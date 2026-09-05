import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:three_js/three_js.dart' as three;

import '../../models/bowl_project.dart';
import '../../rendering/scene_3d.dart';
import '../../rendering/trackpad_orbit_controls.dart';
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
  bool _ready = false;
  int? _builtHash;
  int _highlight = -1;
  three.Vector3 _homePos = three.Vector3(1, 1, 1);
  final three.Vector3 _homeTarget = three.Vector3();

  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() => _ready = true),
      setup: _setup,
      settings: three.Settings(clearColor: 0x1a1611, antialias: widget.antialias),
    );
  }

  @override
  void dispose() {
    _controls?.dispose();
    if (threeJs.mounted) threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

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
    threeJs.addAnimationEvent((dt) => _controls!.update());

    final project = ref.read(projectProvider);
    _rebuild(project);
    _frame(project);
  }

  void _disposeGroup() {
    for (final m in _ringMeshes) {
      m.geometry?.dispose();
      m.material?.dispose();
    }
    _ringMeshes.clear();
    _ringMats.clear();
  }

  void _rebuild(BowlProject project) {
    if (_group != null) {
      threeJs.scene.remove(_group!);
      _disposeGroup();
    }
    final g = three.Group();
    for (final rt in buildRingTriangles(project)) {
      final geo = three.BufferGeometry();
      geo.setAttributeFromString(
          'position', three.Float32BufferAttribute.fromList(rt.positions, 3));
      geo.setAttributeFromString(
          'color', three.Float32BufferAttribute.fromList(rt.colors, 3));
      geo.computeVertexNormals();
      final mat = three.MeshPhongMaterial.fromMap({
        'vertexColors': true,
        'side': three.DoubleSide,
        'shininess': 14,
        'specular': 0x0d0d0d,
        'emissive': 0x000000,
      });
      final mesh = three.Mesh(geo, mat);
      mesh.userData['ringIndex'] = rt.ringIndex;
      g.add(mesh);
      _ringMeshes.add(mesh);
      _ringMats.add(mat);
    }
    _group = g;
    threeJs.scene.add(g);
    _builtHash = identityHashCode(project);
    _applyHighlight();
  }

  void _applyHighlight() {
    for (var i = 0; i < _ringMats.length; i++) {
      _ringMats[i].emissive?.setFromHex32(i == _highlight ? 0x6b4a12 : 0x000000);
      _ringMats[i].needsUpdate = true;
    }
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
    if (hits.isEmpty) return;
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

    if (_ready) {
      if (identityHashCode(project) != _builtHash) {
        _rebuild(project);
        _frame(project);
      }
      final hi = project.rings.indexWhere((r) => r.id == selId);
      if (hi != _highlight) {
        _highlight = hi;
        _applyHighlight();
      }
    }

    return Stack(
      children: [
        Positioned.fill(child: threeJs.build()),
        Positioned(
          left: 14,
          bottom: 12,
          child: Text(
            '3D · DRAG TO ORBIT · SCROLL / PINCH TO ZOOM · CLICK TO SELECT',
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
