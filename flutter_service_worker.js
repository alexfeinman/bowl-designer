'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "774b3406987ba8c3620242213c61b6a7",
"version.json": "90f7162f113a89f0d695675a1328e303",
"index.html": "ffe32b91891e4f022f2d8c1d29150c63",
"/": "ffe32b91891e4f022f2d8c1d29150c63",
"main.dart.js": "d03060dc6d140c88e197ee661b8b1994",
"gles_bindings.js": "9c00c4a51e5c48933957966960684267",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"favicon.png": "300c44aa22d924983a1b4e102c6d86f2",
"icons/Icon-192.png": "164e7a3fd308153bb545e048c09597ca",
"icons/Icon-maskable-192.png": "eb0e4706fca5ed9f123779460a978cb7",
"icons/Icon-maskable-512.png": "6f44644ba74314e40f6489f425678540",
"icons/Icon-512.png": "7a12450c70ba85dde876c3ef370c121a",
"manifest.json": "987fe45edbb60ecfe71ad01e1646d83e",
"assets/AssetManifest.json": "1c3579bda3876ec231677b370d4b25a9",
"assets/NOTICES": "e65fa1aa998babd0eab2cda7f1283657",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "589f6eb1d1d0dd0e3b679b0d4b6bc227",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/three_js_controls/assets/joystick_background.png": "8c9aa78348b48e03f06bb97f74b819c9",
"assets/packages/three_js_controls/assets/joystick_knob.png": "bb0811554c35e7d74df6d80fb5ff5cd5",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "5f6e8eee25fcee47dd5644f43e72dac5",
"assets/fonts/MaterialIcons-Regular.otf": "56027ebc44f06477d6413a764e5a912d",
"assets/assets/textures/wood/ash.jpg": "f4b9738a1f72219e3b4e3315331f98c2",
"assets/assets/textures/wood/CREDITS.md": "7dcd6c0783af154894b3f918c9c13bac",
"assets/assets/textures/wood/wenge.jpg": "775858e16da74010d425b2d6083f4ba8",
"assets/assets/textures/wood/cherry.jpg": "f8fe5939f81e8c64189ae623bfb7da5a",
"assets/assets/textures/wood/maple.jpg": "dacc76d370eb9f4dc0a7ebbf06dbfe8f",
"assets/assets/textures/wood/oak.jpg": "03b0884f621cf28c0236661629fe9c3c",
"assets/assets/textures/wood/walnut.jpg": "63a0bdc9c6c62e7708ca5319d690b08b",
"assets/assets/textures/wood/purpleheart.jpg": "a20fe0ab2dbd296d8ac0937ced416577",
"assets/assets/textures/wood/padauk.jpg": "fb7ecb2f38da623972c9725e377eae12",
"assets/assets/icons/rotate.svg": "e7c9248cef17d85dccf6b3d638e49818",
"assets/assets/icons/stave.svg": "281e7944edfaec783db4aad7440e31fd",
"assets/assets/icons/dimensions.svg": "586bead53d7967b612befaad2da1a9f6",
"assets/assets/icons/cut_list.svg": "6f29e8b2f862222dd2bf3169621edd4b",
"assets/assets/icons/cube.svg": "9553ad7e01f9c4909d6bb9e8a8f5a5bd",
"assets/assets/icons/bowl.svg": "135bf98544a650f8308310d183720a3a",
"assets/assets/icons/save.svg": "18f84bb610a6257ef4fc230b53557c58",
"assets/assets/icons/redo.svg": "30d7524f09e2630797a7fdefb97b584f",
"assets/assets/icons/compound.svg": "593ece1522e00d1b9a68f8b44b9069cf",
"assets/assets/icons/disk.svg": "aa03c123b6ee5d11bec24ebbffc36fae",
"assets/assets/icons/add_ring.svg": "44b2b6057adb00ac16652a2cdde9c273",
"assets/assets/icons/remove_ring.svg": "259f32d9b349844da4e4197012faba70",
"assets/assets/icons/grain.svg": "afa7d514b55d4f345a34539506a2aef6",
"assets/assets/icons/undo.svg": "a6dec649320029b875965bffc69ca099",
"assets/assets/icons/lumber.svg": "2c3ef966f9632dea438c3e4a83b144ea",
"assets/assets/icons/ring.svg": "5f56808b6369ce978a2b40bb7d1128fc",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
