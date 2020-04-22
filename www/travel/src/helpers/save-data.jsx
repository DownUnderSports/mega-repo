import { openDB } from 'idb/with-async-ittr'
import currentSchema from 'database/schema'

function createIndexedDB() {
  try {
    if (!('indexedDB' in global)) {return null;}
  } catch(err) {
    if(!(err instanceof ReferenceError)) return null
  }

  return openDB(
    'down-under-travel',
    4,
    {
      async upgrade(db, oldVersion, newVersion, tx) {
        for(let storeKey in currentSchema) {
          if(!db.objectStoreNames.contains(storeKey)) {
            const { config, indexes } = currentSchema[storeKey]
            const store = db.createObjectStore(storeKey, config);
            for (let i = 0; i < indexes.length; i++) {
              store.createIndex(...indexes[i])
            }
          }
        }
        await tx.done;
      }
    }
  )
}

const openCurrentDB = createIndexedDB();

async function runTransaction(storeKey, recordsFunction, errorMessage, getTransaction = false) {
  if(!storeKey) throw new Error("storeKey is required")

  try {
    if(!('indexedDB' in global)) throw new Error("Unsupported Browser")
  } catch(err) {
    if(!(err instanceof ReferenceError)) throw new Error("Unsupported Browser")
  }

  const db = await openCurrentDB,
        tx = db.transaction(storeKey, 'readwrite')

  try {
    recordsFunction(getTransaction ? tx : tx.objectStore(storeKey))

    return await tx.done;
  } catch(err) {
    tx.abort();
    throw Error(`${errorMessage || 'Transaction Failed'}: ${err.toString()}`);
  }
}

export function saveToDB({ storeKey, records = [], errorMessage }) {
  return runTransaction(
    storeKey,
    (store) => records.map(event => store.put(event)),
    errorMessage || 'Record(s) were not saved'
  )
}

export function deleteFromDB({ storeKey, idKey = 'id', records = [], errorMessage }) {
  return runTransaction(
    storeKey,
    (store) => records.map(event => store.delete(event[idKey || 'id'])),
    errorMessage || 'Record(s) were not removed'
  )
}

export function getFromDB({ storeKey, storeCallback, errorMessage, getTransaction = false }) {
  return runTransaction(
    storeKey,
    storeCallback,
    errorMessage || 'Record(s) were not retrieved',
    getTransaction
  )
}

export function getAllFromDB({storeCallback, ...options}) {
  return getFromDB({...options, storeCallback: (store) => storeCallback(store.getAll()), getTransaction: false })
}
