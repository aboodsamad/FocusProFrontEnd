'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "c8648ea477a11188acf6f29e696e434e",
"assets/AssetManifest.bin.json": "cceaf5da426c849467d1d500f42d293a",
"assets/assets/images/books/book_100.png": "176eaf0e301b55f0304fba229f3fec5c",
"assets/assets/images/books/book_101.png": "43c98b1d653d4714bc8fb27300005e41",
"assets/assets/images/books/book_102.png": "286e5e3513e3528060bf0acc5f542017",
"assets/assets/images/books/book_103.png": "3cc6569b80ebd7c3a654d95294d016bf",
"assets/assets/images/books/book_104.png": "8a76b4664c581bfc3a0ed0c5c24d6532",
"assets/assets/images/books/book_105.png": "84442cf87dab5206c91d674cb998ce1b",
"assets/assets/images/books/book_106.png": "d8e59e549fb009d2b821d88e32965039",
"assets/assets/images/books/book_107.png": "7658a8ce29d2c72971a754eb585666e2",
"assets/assets/images/books/book_108.png": "f451d742c8b7a30fd6cb2dcf0c163b77",
"assets/assets/images/books/book_109.png": "99ff2d0382d162faf627114e4bd43d1d",
"assets/assets/images/books/book_11.png": "b3be9e3a798bfe24013cbbdca0039e51",
"assets/assets/images/books/book_110.png": "ab782ca1326ba939c83ff825136e08d9",
"assets/assets/images/books/book_111.png": "38e01d8f8577a318144f198f340141fe",
"assets/assets/images/books/book_112.png": "f072de78ca85d498a200805d68079c5d",
"assets/assets/images/books/book_113.png": "f072de78ca85d498a200805d68079c5d",
"assets/assets/images/books/book_114.png": "49e9785dc1854653831e3f930a93679b",
"assets/assets/images/books/book_115.png": "36541417bf8c67ef63938751ae7125dd",
"assets/assets/images/books/book_116.png": "6a4c2f8d3f8cbaa5a17f48be4e39f2cf",
"assets/assets/images/books/book_117.png": "73993add2fd263e8054b1f96f3155267",
"assets/assets/images/books/book_118.png": "ede19d834250a5f4e779a8c7cf4a6d15",
"assets/assets/images/books/book_119.png": "9b918fff0309bd9cacb7f4f940d180d3",
"assets/assets/images/books/book_12.png": "bdc60ab218f946f144c7e0f8caf17e85",
"assets/assets/images/books/book_120.png": "624fa833fd6fbc916a78cdaba1416981",
"assets/assets/images/books/book_121.png": "a85f516c6cebe040101aded7d3905eb7",
"assets/assets/images/books/book_122.png": "ebce7efb6ab205ea8a141da3d3aaaae8",
"assets/assets/images/books/book_123.png": "b76521e4beeea34dbfebe74f60e5f1a9",
"assets/assets/images/books/book_124.png": "c0a875073aa3b64c49fb7570a61cb99e",
"assets/assets/images/books/book_125.png": "5276d15c383a5917c6f0156b8e35a670",
"assets/assets/images/books/book_126.png": "43257c16ed00c2a8dbc9276e2390706e",
"assets/assets/images/books/book_13.png": "3910b9db1632b2fe7dbd330cdce44370",
"assets/assets/images/books/book_14.png": "5c4876b123ecbcc8793f35f446d885f0",
"assets/assets/images/books/book_15.png": "7ae5f5d73794063af2e8179564b0f587",
"assets/assets/images/books/book_16.png": "07f8082f9714c3f9522713a8b9e2ffa9",
"assets/assets/images/books/book_17.png": "aef3da90a3f89dcd777da4c9622dee6b",
"assets/assets/images/books/book_18.png": "c8c902f18e1d80e1f3c4c49c4b22099c",
"assets/assets/images/books/book_19.png": "48ae10fba726c92c3b80b71c4a7a0b4f",
"assets/assets/images/books/book_20.png": "c6c970310afde70515b074393d9cce9c",
"assets/assets/images/books/book_21.png": "d1db6a5c3b0ab8e0af7cf5a4e9b6e78d",
"assets/assets/images/books/book_22.png": "dac39ae033edc688ad8244596cb9775e",
"assets/assets/images/books/book_23.png": "ee79f6bea966591f19cc648425c2a71f",
"assets/assets/images/books/book_24.png": "b90ba6c9249ab0e35c511a6ce6e92144",
"assets/assets/images/books/book_25.png": "f4c040b0a7cf7e64b7aea85fe0ff72fc",
"assets/assets/images/books/book_26.png": "db0af3f22e35ffd4b7dddce06fbcd8cc",
"assets/assets/images/books/book_27.png": "67a61174f84f753f92f5c7962271e219",
"assets/assets/images/books/book_28.png": "86bf29b44422c1fb179fc5522cf7c4ee",
"assets/assets/images/books/book_29.png": "ab8f2de1ee4cd9d312bfe1f6c06173ed",
"assets/assets/images/books/book_30.png": "960a1a29d74374faf87b85749bb89680",
"assets/assets/images/books/book_31.png": "5b6c0455d118749927efb80aa9d76870",
"assets/assets/images/books/book_32.png": "a04e0bbe1001c820e156952234a92daa",
"assets/assets/images/books/book_34.png": "62a754db879bdd06311016d985ccde27",
"assets/assets/images/books/book_35.png": "9d6699416fa96fe69689fb3aac76ed88",
"assets/assets/images/books/book_36.png": "9780713a695931a9032560c1c66946bb",
"assets/assets/images/books/book_37.png": "7cc2a9e8923c8cfe602ad162a9dcc357",
"assets/assets/images/books/book_38.png": "141672dc4926568260ce18e1c75e2b8a",
"assets/assets/images/books/book_39.png": "2590dcfbe30a196f1853722cad579500",
"assets/assets/images/books/book_40.png": "d978a435c0316b7326d5bf2ba3a65acb",
"assets/assets/images/books/book_41.png": "d7b24795edde44e5c6e113ce1d995c36",
"assets/assets/images/books/book_42.png": "7c1faaf17d321c86f6ff1b5968af2702",
"assets/assets/images/books/book_43.png": "626a5581d409ad55d0a4be7b52949a6c",
"assets/assets/images/books/book_44.png": "ae1a03f397222d17c559216d1800d50e",
"assets/assets/images/books/book_45.png": "d978a435c0316b7326d5bf2ba3a65acb",
"assets/assets/images/books/book_46.png": "2e89304a316b3364b9ac117db340f2a8",
"assets/assets/images/books/book_47.png": "5d8897e1bf35f5cac738a004787bc474",
"assets/assets/images/books/book_48.png": "1f671ee862b152ea8c45da02eb6fc428",
"assets/assets/images/books/book_49.png": "9c07872ad4e60d8b293cfad42b48bc87",
"assets/assets/images/books/book_50.png": "e966a72be8c13edc3e564b28be5efdbd",
"assets/assets/images/books/book_51.png": "00f557d8cb0852f5e149d9c1bcb7da88",
"assets/assets/images/books/book_52.png": "321204c3a1b8858b1e42a3fdc0e0d9a9",
"assets/assets/images/books/book_53.png": "04718455bb5703f3a42078a4e3d85c92",
"assets/assets/images/books/book_54.png": "fd3557937d183faa6019539ae1585ccc",
"assets/assets/images/books/book_55.png": "6224ec50cd3dd453209ba2f3db79d958",
"assets/assets/images/books/book_56.png": "5ee47b7866b89d32ffb27d8093c7f506",
"assets/assets/images/books/book_57.png": "1cf02f6059d6b1641f3b15a931949af7",
"assets/assets/images/books/book_58.png": "3a67674bc75bbf9141854b4f2e2f43c8",
"assets/assets/images/books/book_59.png": "0a4eeb4e83fe88b0b1d4811e97390fbb",
"assets/assets/images/books/book_60.png": "de4bd4ef739b06408f5e091cef30890e",
"assets/assets/images/books/book_61.png": "1043d75b0cfe2c21efd7c5abee0eb8b7",
"assets/assets/images/books/book_62.png": "e97a564228f1934b2edcd182e197c97c",
"assets/assets/images/books/book_63.png": "b2f855383ee50dc667439129dfe84df9",
"assets/assets/images/books/book_64.png": "eb7ef6a52326c08a47b7438e4a558319",
"assets/assets/images/books/book_65.png": "b22a78562c05e6b3976bcb0bb84658f6",
"assets/assets/images/books/book_66.png": "e3dfd885ad0ea51b0131a46f1fbbda15",
"assets/assets/images/books/book_67.png": "0da18de7d9daecd60c1ddd319ca175d1",
"assets/assets/images/books/book_68.png": "be0387ba518944deda7e99daf0dcda3c",
"assets/assets/images/books/book_69.png": "4cdf5e11dc6da41211d7f0fb232c9083",
"assets/assets/images/books/book_70.png": "8fca23ed380c715e0f45f9acdfe38efb",
"assets/assets/images/books/book_71.png": "af237ec94e084b5987a796ea7c444d02",
"assets/assets/images/books/book_72.png": "5276e111c482b73e0005690b0c2ded72",
"assets/assets/images/books/book_73.png": "8eee4cfed668061dd077830768f70530",
"assets/assets/images/books/book_74.png": "0a32af1736478aaffdcb0c1e9722819a",
"assets/assets/images/books/book_75.png": "3e9a0aa3052cc1e83cfb2aeac68e6d2c",
"assets/assets/images/books/book_76.png": "afe9eba1d43cbca76707ddfc72170389",
"assets/assets/images/books/book_77.png": "0760effc7372f2174905a5e9d68f882a",
"assets/assets/images/books/book_78.png": "8677446858b030c7804b043497a93a09",
"assets/assets/images/books/book_79.png": "1d36be4f4b3f6f0d5f4a9a48d0572c84",
"assets/assets/images/books/book_80.png": "fb10e9e3b0cd27bbf33a821f0d9c2e2a",
"assets/assets/images/books/book_82.png": "aef3da90a3f89dcd777da4c9622dee6b",
"assets/assets/images/books/book_83.png": "3856899157fdb918af2ed7d932431cff",
"assets/assets/images/books/book_84.png": "5b0ce23fac8cf6a959f5d6812c208e36",
"assets/assets/images/books/book_85.png": "7388c3d09034f9df210141b6d539124a",
"assets/assets/images/books/book_86.png": "57dbb945ebdbf4519f8f51863aab5538",
"assets/assets/images/books/book_87.png": "a8841e2eb12a080a1bfe285ec1d96b98",
"assets/assets/images/books/book_88.png": "7f03effb279e5cff8fd8a6323a816aa3",
"assets/assets/images/books/book_89.png": "31eb680c522caa172142199c07d57b38",
"assets/assets/images/books/book_90.png": "6916f0c52cc17d3d24af1d8dfdd43c79",
"assets/assets/images/books/book_91.png": "a2398e53303eb6e9db6e252827f709ce",
"assets/assets/images/books/book_92.png": "0c160a3c26d0c67d3bb4c2133296f51f",
"assets/assets/images/books/book_93.png": "677a0aa0eb0ddd64b8f591e93f00f28a",
"assets/assets/images/books/book_94.png": "e5a095a9247a9d7397675c01b75209ef",
"assets/assets/images/books/book_95.png": "c318f5d45bc24aff4dbf5ab6fb273101",
"assets/assets/images/books/book_96.png": "0a9c639176ee074e5cd88d4981ae9766",
"assets/assets/images/books/book_97.png": "b10307ddf0efc6a676fceff5e1bd6766",
"assets/assets/images/books/book_98.png": "872f1de9029fc59a48453b0da8e9e093",
"assets/assets/images/games/color_match.png": "a9ba4543b9c565ed7e2e7e9faf02d1d8",
"assets/assets/images/games/memory_matrix.png": "467696a947c2da5038a04e3cea905c23",
"assets/assets/images/games/number_stream.png": "e9487900c472ad3fe723942277a12f44",
"assets/assets/images/games/pattern_trail.png": "f49c8754e1dd96802d7af76585a93c03",
"assets/assets/images/games/speed_match.png": "9d4906e0dcd4519ee97e51442cb84715",
"assets/assets/images/games/sudoku.png": "9735195df69aec249ce90366c8255680",
"assets/assets/images/games/train_of_thought.png": "6c336b3c73fe97f94818d1a90a9e36f0",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "bb17cbf9b7bbcefbb631a9fabf09ca25",
"assets/NOTICES": "78737f0190cb993b11bc866c3deba9a1",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "673272b892b17106a175f3137ea56edc",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "c99b0878f976f60e62efa8af33a75414",
"/": "c99b0878f976f60e62efa8af33a75414",
"main.dart.js": "867fe5823b13f44d798e4557b2a72ffa",
"manifest.json": "7af530c02934ea65fa298ae3b9a5e098",
"notification_sw.js": "666e827717804df4ecdbd2e0849d7ab1",
"version.json": "586015f55bce684ffc33de4b2e7d9462"};
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
