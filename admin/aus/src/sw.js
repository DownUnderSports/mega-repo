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

  workbox.precaching.precacheAndRoute([]);

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
    'down-under-aus-queue',
  );

  const bgSaveToIDBPlugin = new workbox.backgroundSync.Plugin(
    'down-under-aus-idb-queue',
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

  workbox.routing.registerRoute(
    /\/static\/.*$/,
    cacheFirstAssets,
    'GET'
  );

  workbox.routing.setDefaultHandler(networkFirstAssets);
} else {
  console.log(`Boo! Workbox didn't load 😬`);
}
