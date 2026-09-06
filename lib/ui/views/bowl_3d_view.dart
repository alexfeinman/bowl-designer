import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:three_js/three_js.dart' as three;

import '../../models/bowl_project.dart';
import '../../rendering/scene_3d.dart';
import '../../rendering/trackpad_orbit_controls.dart';
import '../../rendering/wood_textures.dart';
import '../../state/project_controller.dart';
import '../theme.dart';

/// GPU (WebGL via three_js) 3D view: builds the bowl mesh in memory and lets the
/// hardware depth-buffer + light it. Replaces the software rasterizer — correct
/// occlusion, fast and fluid. [antialias] is applied at renderer construction,
/// so the parent keys this widget on it to recreate when it changes.
class Bowl3DView extends ConsumerStatefulWidget {
  const Bowl3DView({super.key, required this.antialias});
  final bool antialias;

  @override
  ConsumerState<Bowl3DView> createState() => _Bowl3DViewState();
}

class _Bowl3DViewState extends ConsumerState<Bowl3DView> {
  late final three.ThreeJS threeJs;
  three.OrbitControls? _controls;
  three.Group? _group;
  final List<three.Mesh> _ringMeshes = [];
  final List<three.MeshPhongMaterial> _ringMats = [];
  // Parallel to _ringMats: the ring each material mesh belongs to (a ring can
  // now span several meshes, one per species), and the grain asset it wants.
  final List<int> _ringOfMat = [];
  final List<String> _matAsset = [];
  bool _ready = false;
  int? _builtHash;
  bool _builtTurned = false;
  bool _builtGrain = false;
  double? _builtWall;
  int _highlight = -1;
  three.Vector3 _homePos = three.Vector3(1, 1, 1);
  final three.Vector3 _homeTarget = three.Vector3();

  bool _disposed = false;
  bool _pumpScheduled = false;
  bool _rendering = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () {
        setState(() => _ready = true);
        _warmup(90); // render across init/layout/texture settling, then idle
      },
      setup: _setup,
      // Render on demand (see _pump) instead of every ticker frame, so an idle
      // 3D view uses no GPU/CPU. This is essential on machines that fall back
      // to software GL (e.g. some Linux boxes were pegging all cores) and saves
      // battery everywhere.
      settings: three.Settings(
          clearColor: 0x1a1611, antialias: widget.antialias, animate: false),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controls?.dispose();
    if (threeJs.mounted) threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

  /// Mark the scene dirty and ensure a frame is pumped. Cheap to call often.
  void _requestRender() {
    _dirty = true;
    _schedulePump();
  }

  /// Render on each of the next [frames] frames. The platform view's real size
  /// (and the GL texture) can settle a beat after setup — the on-demand loop
  /// would otherwise present one early, wrongly-sized frame and then idle,
  /// leaving the view blank. This carries it through the settle, then stops.
  void _warmup(int frames) {
    if (_disposed || frames <= 0) return;
    _requestRender();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmup(frames - 1));
  }

  void _schedulePump() {
    if (_pumpScheduled || _rendering || _disposed) return;
    _pumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pumpScheduled = false;
      _pump();
    });
  }

  /// Apply any control (camera) changes and render a single frame; keep pumping
  /// while the controls are still easing (damping) or another change arrived.
  Future<void> _pump() async {
    if (!_ready || _disposed || !threeJs.mounted) return;
    _rendering = true;
    _dirty = false;
    final moving = _controls?.update() ?? false;
    try {
      await threeJs.render();
    } catch (_) {
      // A transient GL/init hiccup shouldn't kill the pump; try again next frame.
      _dirty = true;
    }
    _rendering = false;
    if (_disposed) return;
    if (moving || _dirty) _schedulePump();
  }

  void _onControlsChange(dynamic _) => _requestRender();

  Future<void> _setup() async {
    threeJs.scene = three.Scene();
    threeJs.camera = three.PerspectiveCamera(
        45, threeJs.width / threeJs.height, 0.1, 100000);

    threeJs.scene.add(three.AmbientLight(0xffffff, 0.55));
    final key = three.DirectionalLight(0xffffff, 0.8)
      ..position.setValues(0.5, 1.0, 0.7);
    threeJs.scene.add(key);
    final fill = three.DirectionalLight(0xffffff, 0.3)
      ..position.setValues(-0.6, -0.3, -0.8);
    threeJs.scene.add(fill);

    _controls = TrackpadOrbitControls(threeJs.camera, threeJs.globalKey,
        onClick: _pickAt)
      ..enableDamping = true
      ..dampingFactor = 0.08;
    // Render only when the camera actually changes (drag / zoom / damping ease).
    _controls!.addEventListener('change', _onControlsChange);
    // Re-render when the view is resized (also nudges the first correctly-sized
    // frame once the platform view settles).
    threeJs.windowResizeUpdate = (_) => _requestRender();

    _builtTurned = ref.read(turnedBowlProvider);
    _builtWall = ref.read(xrayWallProvider);
    _builtGrain = ref.read(woodGrainProvider);
    final project = ref.read(projectProvider);
    _rebuild(project);
    _frame(project);
  }

  void _disposeGroup() {
    for (final m in _ringMeshes) {
      m.geometry?.dispose();
      // The grain textures are shared and cached (WoodTextures) — detach so the
      // material's dispose() does not free a texture other meshes still use.
      m.material?.map = null;
      m.material?.dispose();
    }
    _ringMeshes.clear();
    _ringMats.clear();
    _ringOfMat.clear();
    _matAsset.clear();
  }

  void _rebuild(BowlProject project) {
    if (_group != null) {
      threeJs.scene.remove(_group!);
      _disposeGroup();
    }
    final g = three.Group();
    final tris = _builtTurned
        ? buildTurnedBowlTriangles(project, wallMm: _builtWall)
        : buildRingTriangles(project);
    final grain = _builtGrain;
    final pending = <String>{};
    for (final rt in tris) {
      final geo = three.BufferGeometry();
      geo.setAttributeFromString(
          'position', three.Float32BufferAttribute.fromList(rt.positions, 3));
      geo.setAttributeFromString(
          'color', three.Float32BufferAttribute.fromList(rt.colors, 3));
      geo.setAttributeFromString(
          'uv', three.Float32BufferAttribute.fromList(rt.uvs, 2));
      geo.computeVertexNormals();
      // A turned-bowl glue line is always a flat dark bucket, never textured.
      final isGap = rt.materialId == kGapMaterialId;
      final assetId = WoodTextures.assetIdRaw(rt.materialId, rt.baseColor);
      final mat = three.MeshPhongMaterial.fromMap({
        'vertexColors': true,
        'side': three.DoubleSide,
        'shininess': grain ? 24 : 14,
        'specular': grain ? 0x141414 : 0x0d0d0d,
        'emissive': 0x000000,
      });
      if (grain && !isGap) {
        // Grain photo × tint × grayscale shade. Tint is white for true-match
        // species and a hue shift for the reused exotics. The texture may still
        // be loading, in which case we show the tinted flat colour and attach
        // the map when it arrives.
        mat.color.setFromHex32(WoodTextures.tintFor(assetId) & 0xFFFFFF);
        final tex = WoodTextures.cached(assetId);
        if (tex != null) {
          mat.map = tex;
        } else {
          // No texture yet: fall back to the species colour so it isn't white.
          mat.color.setFromHex32(rt.baseColor & 0xFFFFFF);
          pending.add(assetId);
        }
      } else {
        mat.color.setFromHex32(rt.baseColor & 0xFFFFFF);
      }
      mat.needsUpdate = true;
      final mesh = three.Mesh(geo, mat);
      mesh.userData['ringIndex'] = rt.ringIndex;
      g.add(mesh);
      _ringMeshes.add(mesh);
      _ringMats.add(mat);
      _ringOfMat.add(rt.ringIndex);
      _matAsset.add(isGap ? kGapMaterialId : assetId);
    }
    _group = g;
    threeJs.scene.add(g);
    _builtHash = identityHashCode(project);
    _applyHighlight();
    if (grain && pending.isNotEmpty) {
      WoodTextures.ensure(pending, _onGrainLoaded);
    }
  }

  /// A grain texture finished decoding: attach it to any material that wanted it
  /// and is still showing the flat fallback, then re-render.
  void _onGrainLoaded() {
    if (_disposed || !_builtGrain) return;
    var changed = false;
    for (var i = 0; i < _ringMats.length; i++) {
      if (_matAsset[i] == kGapMaterialId) continue; // glue lines stay flat
      if (_ringMats[i].map != null) continue;
      final tex = WoodTextures.cached(_matAsset[i]);
      if (tex != null) {
        _ringMats[i].map = tex;
        _ringMats[i].color.setFromHex32(WoodTextures.tintFor(_matAsset[i]) & 0xFFFFFF);
        _ringMats[i].needsUpdate = true;
        changed = true;
      }
    }
    if (changed) _requestRender();
  }

  void _applyHighlight() {
    for (var i = 0; i < _ringMats.length; i++) {
      _ringMats[i].emissive
          ?.setFromHex32(_ringOfMat[i] == _highlight ? 0x6b4a12 : 0x000000);
      _ringMats[i].needsUpdate = true;
    }
    _requestRender();
  }

  void _frame(BowlProject project) {
    final r = project.maxOuterDiameterMm / 2;
    final h = project.totalHeightMm;
    final extent = math.max(r, h / 2);
    final dist = extent / math.tan(45 * math.pi / 180 / 2) * 1.5;
    _controls!.target.setValues(0, 0, 0);
    threeJs.camera.position.setValues(dist * 0.6, dist * 0.5, dist * 0.78);
    threeJs.camera.near = math.max(dist / 1000, 0.05);
    threeJs.camera.far = dist * 100;
    threeJs.camera.updateProjectionMatrix();
    _controls!.update();
    _homePos = threeJs.camera.position.clone();
  }

  void _resetView() {
    if (!_ready) return;
    threeJs.camera.position.setFrom(_homePos);
    _controls!.target.setFrom(_homeTarget);
    _controls!.update();
    _requestRender();
  }

  /// Ray-pick a ring from an element-local pixel position (from the controls).
  void _pickAt(double x, double y) {
    if (!_ready || _ringMeshes.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final s = box.size;
    if (s.width <= 0 || s.height <= 0) return;
    final ndc = three.Vector2((x / s.width) * 2 - 1, -((y / s.height) * 2 - 1));
    final ray = three.Raycaster();
    ray.setFromCamera(ndc, threeJs.camera);
    final hits = ray.intersectObjects(_ringMeshes, false);
    if (hits.isEmpty) {
      // Clicking empty space hides the highlight here without disturbing the
      // ring list's selection.
      ref.read(threeDHighlightSuppressedProvider.notifier).state = true;
      return;
    }
    final ri = hits.first.object?.userData['ringIndex'];
    final rings = ref.read(projectProvider).rings;
    if (ri is int && ri >= 0 && ri < rings.length) {
      ref.read(selectionControllerProvider.notifier).select(rings[ri].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final selId = ref.watch(selectedRingIdProvider);

    final suppressed = ref.watch(threeDHighlightSuppressedProvider);
    final turned = ref.watch(turnedBowlProvider);
    final wall = ref.watch(xrayWallProvider);
    final grain = ref.watch(woodGrainProvider);

    if (_ready) {
      if (identityHashCode(project) != _builtHash ||
          turned != _builtTurned ||
          wall != _builtWall ||
          grain != _builtGrain) {
        // Rebuild the mesh in place but keep the camera where the user left it —
        // editing a ring should not snap the view back to the framed home.
        _builtTurned = turned;
        _builtWall = wall;
        _builtGrain = grain;
        _rebuild(project);
      }
      final hi = suppressed ? -1 : project.rings.indexWhere((r) => r.id == selId);
      if (hi != _highlight) {
        _highlight = hi;
        _applyHighlight();
      }
    }

    return Stack(
      children: [
        // three_js sizes its GL texture and camera aspect from MediaQuery.size,
        // which is the whole app window — but this view only occupies a pane.
        // Override MediaQuery with the pane's real size so the texture and the
        // camera aspect track the pane (no stretch), and so the package's
        // window-resize path recomputes against the pane on every resize.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final mq = MediaQuery.of(ctx);
              return MediaQuery(
                data: mq.copyWith(size: constraints.biggest),
                child: threeJs.build(),
              );
            },
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: _TurnedToggle(
            turned: turned,
            wallMm: wall,
            onTap: () => ref.read(turnedBowlProvider.notifier).state = !turned,
          ),
        ),
        Positioned(
          left: 14,
          bottom: 12,
          child: Text(
            turned
                ? '3D · TURNED BOWL · DRAG TO ORBIT · SCROLL TO ZOOM'
                : '3D · DRAG TO ORBIT · SCROLL / PINCH TO ZOOM · CLICK TO SELECT',
            style: AppFonts.mono(TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.5))),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: TextButton(
            onPressed: _resetView,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.85),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text('Reset view',
                style: AppFonts.ui(
                    const TextStyle(fontSize: 11.5, color: Colors.white))),
          ),
        ),
      ],
    );
  }
}

/// A pill that toggles the 3D view between the glued rings and the turned bowl.
class _TurnedToggle extends StatelessWidget {
  const _TurnedToggle(
      {required this.turned, required this.wallMm, required this.onTap});
  final bool turned;
  final double? wallMm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFE0A54B);
    return Material(
      color: turned ? accent.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: turned ? accent : Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(turned ? Icons.emoji_food_beverage : Icons.view_in_ar,
                  size: 15,
                  color: turned ? accent : Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 7),
              Text(
                turned ? 'Turned bowl' : 'Show turned',
                style: AppFonts.ui(TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color:
                        turned ? accent : Colors.white.withValues(alpha: 0.85))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
