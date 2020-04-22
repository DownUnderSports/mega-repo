/* global workbox */
/* global importScripts */

/*
Copyright 2018 Google Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'helpers/inject-global'
import models from './models'

//eslint-disable-next-line
const window = self

importScripts('https://storage.googleapis.com/workbox-cdn/releases/4.3.1/workbox-sw.js');

if (workbox) {
  console.log(`Yay! Workbox is loaded 🎉`);

  workbox.precaching.precacheAndRoute([
  {
    "url": "apple-touch-icon-114x114.png",
    "revision": "fb203bc71569c5317444950fa2e2bc2c"
  },
  {
    "url": "apple-touch-icon-120x120.png",
    "revision": "a26218d3aef83bf93cfc9acb32141990"
  },
  {
    "url": "apple-touch-icon-144x144.png",
    "revision": "10f17469f7a6d357ebd4267431a0a79a"
  },
  {
    "url": "apple-touch-icon-152x152.png",
    "revision": "7e98425bb4176c80e2fda0caaba05ec4"
  },
  {
    "url": "apple-touch-icon-57x57.png",
    "revision": "fe8715a2c7ac0af75709f18e6ba50487"
  },
  {
    "url": "apple-touch-icon-60x60.png",
    "revision": "2fc8a42bb3abb0de1df207e4800d5a17"
  },
  {
    "url": "apple-touch-icon-72x72.png",
    "revision": "3b358bfe672f732d5e99b815a18e7aeb"
  },
  {
    "url": "apple-touch-icon-76x76.png",
    "revision": "8da3b50262d126655b725761af652ed3"
  },
  {
    "url": "favicon-128x128.png",
    "revision": "ecaf5a0308abb4cd77df28c25509566d"
  },
  {
    "url": "favicon-16x16.png",
    "revision": "8b87fa4031dcb82683d6de1f7fa7c4ea"
  },
  {
    "url": "favicon-196x196.png",
    "revision": "0b6780806d00c6611f37f041c95a8217"
  },
  {
    "url": "favicon-32x32.png",
    "revision": "c2432b63dc5da55a3c23b11d6aec8777"
  },
  {
    "url": "favicon-96x96.png",
    "revision": "2ea816e7ef5d08f6001615f5698b25ba"
  },
  {
    "url": "index.html",
    "revision": "103a75d5fa9923f868ad4854917ce282"
  },
  {
    "url": "mstile-144x144.png",
    "revision": "10f17469f7a6d357ebd4267431a0a79a"
  },
  {
    "url": "mstile-150x150.png",
    "revision": "1714f3453c9b966deccaa58c720fa91e"
  },
  {
    "url": "mstile-310x310.png",
    "revision": "2e3e19a7167b324d5b5150bfd44e376f"
  },
  {
    "url": "mstile-70x70.png",
    "revision": "ecaf5a0308abb4cd77df28c25509566d"
  },
  {
    "url": "precache-manifest.a606af94d44a5645d88e52e006447615.js",
    "revision": "a606af94d44a5645d88e52e006447615"
  },
  {
    "url": "static/css/15.2614ebd1.chunk.css",
    "revision": "06428f80331faccbba0edfc93484fcc8"
  },
  {
    "url": "static/css/app.45fa6ce8.chunk.css",
    "revision": "8acef7fde88ffc5283a111c3ef13d3ff"
  },
  {
    "url": "static/css/atom-loader.c436b3a9.chunk.css",
    "revision": "443704a7bc0b4b75217bd0fba3085a52"
  },
  {
    "url": "static/css/component-templates-css.94295593.chunk.css",
    "revision": "70e2e6afc8a470b8341ab6534b20f1aa"
  },
  {
    "url": "static/css/index-css.2c19fc9d.chunk.css",
    "revision": "ab14da82c728c4e3c3004f1e542355df"
  },
  {
    "url": "static/css/jelly-box-loader.fcff622c.chunk.css",
    "revision": "132d572077be5e67622368d652a4255e"
  },
  {
    "url": "static/js/0.8625881a.chunk.js",
    "revision": "c225574aafc19b421dd3297f1d576478"
  },
  {
    "url": "static/js/15.90c852c3.chunk.js",
    "revision": "2364903a117e1bdab1705f7936b4ac54"
  },
  {
    "url": "static/js/16.d55c4c22.chunk.js",
    "revision": "cc1a8e0110128dee9bd7632ca9e30b4d"
  },
  {
    "url": "static/js/abortcontroller-polyfill.25cebcca.chunk.js",
    "revision": "39ee0832365bddf0dff41b101422881f"
  },
  {
    "url": "static/js/app.3dcb4ef2.chunk.js",
    "revision": "43dacdbf2309b795b3847116e8bce13f"
  },
  {
    "url": "static/js/atom-loader.e923564d.chunk.js",
    "revision": "5338e237e01ab0f21cbf68621df84dc5"
  },
  {
    "url": "static/js/auth-fetch.d70c9894.chunk.js",
    "revision": "0304bcc5b21c1d4ab23751cfe13bc359"
  },
  {
    "url": "static/js/component-templates-css.526a270a.chunk.js",
    "revision": "fe75a4cbedc07d84a9b96ef16bb9cc43"
  },
  {
    "url": "static/js/fetch-polyfill.17a24253.chunk.js",
    "revision": "d7e881e86834558fce5405dc120979df"
  },
  {
    "url": "static/js/home-page.5917e626.chunk.js",
    "revision": "d920fbc5fe0d954bb42d2542b4a0ac77"
  },
  {
    "url": "static/js/index-css.69541734.chunk.js",
    "revision": "762bd6aaf1239fc5efe7fc4a24657111"
  },
  {
    "url": "static/js/jelly-box-loader.e35dfa37.chunk.js",
    "revision": "a963f03b78dd44e0d539c011279f4fba"
  },
  {
    "url": "static/js/main.e0f26ca9.chunk.js",
    "revision": "5ef82ab23849e14b0fa53d3b13f83061"
  },
  {
    "url": "static/js/proxy-page.35bde80e.chunk.js",
    "revision": "1ec1d7d7570a02c6aae03325c903135c"
  },
  {
    "url": "static/js/react.ef2ac64f.chunk.js",
    "revision": "4fc2c61124204d4710640337205c18fc"
  },
  {
    "url": "static/js/runtime~main.b4e4f740.js",
    "revision": "04d08862a9af3b4d24dce751915d1289"
  },
  {
    "url": "static/js/site-polyfills.4410c0fe.chunk.js",
    "revision": "951f9ec3e945c4dcec20d15443eca577"
  },
  {
    "url": "static/media/dus-logo.f4378276.png",
    "revision": "f43782767fd6f138cbe14dc8d5fbd9d7"
  }
]);

  //eslint-disable-next-line
  self.addEventListener('message', (event) => {
    console.log(event)
    if (event.data && event.data.type === 'SKIP_WAITING') {
      //eslint-disable-next-line
      self.skipWaiting();
    }
  });

  //eslint-disable-next-line
  self.addEventListener('sync', function(event) {
    console.log(event)
  });

  const bgSyncPlugin = new workbox.backgroundSync.Plugin(
    'down-under-travel-queue',
  );

  const bgSaveToIDBPlugin = new workbox.backgroundSync.Plugin(
    'down-under-travel-idb-queue',
    {
      onSync: async ({queue}) => {
        let entry;
        //eslint-disable-next-line
        while (entry = await queue.shiftRequest()) {
          try {
            const result = await fetch(entry.request);

            if(/\/get_model_data\//.test(entry.request.url)) {
              try {
                await (models[entry.request.url.replace(/.*\/get_model_data\//, '').replace(/\.json.*/, '')].parseServerData(result))
              } catch(err) {
                console.error(err, entry)
              }
            }

            console.info('Replay successful for request', entry);

          } catch (error) {

            console.error('Replay failed for request', entry, error);

            entry.metadata = entry.metadata || { retries: 5 }

            entry.metadata.retries = +(entry.metadata.retries || 5) - 1

            if(entry.metadata.retries) await queue.pushRequest(entry);

            throw error;
          }
        }
        console.log('Replay complete!');
      },
    }
  );

  const networkWithBackgroundSync = new workbox.strategies.NetworkOnly({
    plugins: [bgSyncPlugin],
  });

  const networkWithBackgroundSave = new workbox.strategies.NetworkOnly({
    plugins: [bgSaveToIDBPlugin],
  });

  const cacheFirstAssets = new workbox.strategies.CacheFirst({
    cacheName: 'cachedAsssets',
    plugins: [
      new workbox.expiration.Plugin({
        maxEntries: 60,
        maxAgeSeconds: 30 * 24 * 60 * 60, // 30 Days
      }),
    ],
  });

  const networkFirstAssets = new workbox.strategies.NetworkFirst({
    cacheName: 'networkedAsssets',
    networkTimeoutSeconds: 25,
    plugins: [
      new workbox.expiration.Plugin({
        maxEntries: 60,
        maxAgeSeconds: 30 * 24 * 60 * 60, // 30 Days
      }),
    ],
  });

  workbox.routing.registerRoute(
    /get_model_data/,
    networkWithBackgroundSave,
  );

  workbox.routing.registerRoute(
    /.*/,
    networkWithBackgroundSync,
    'PATCH'
  );

  workbox.routing.registerRoute(
    /.*/,
    networkWithBackgroundSync,
    'POST'
  );

  workbox.routing.registerRoute(
    /.*/,
    networkWithBackgroundSync,
    'PUT'
  );

  workbox.routing.registerRoute(
    /.*/,
    networkWithBackgroundSync,
    'DELETE'
  );

  // workbox.routing.registerRoute(
  //   /\/static\/.*$/,
  //   cacheFirstAssets,
  //   'GET'
  // );

  workbox.routing.setDefaultHandler(networkFirstAssets);
} else {
  console.log(`Boo! Workbox didn't load 😬`);
}
