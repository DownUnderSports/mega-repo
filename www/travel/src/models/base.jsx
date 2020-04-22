import { saveToDB, deleteFromDB, getAllFromDB } from 'helpers/save-data'
import StreamJsonArray from 'helpers/stream-json-array'
import currentSchema from 'database/schema'

export default class BaseModel {
  constructor() {
    this.state = {
      data: [],
      lastUpdated: '',
      offline: true,
      total: 0,
      deleted: 0,
    }
    this.callbacks = []
    this.streamCallbacks = []
  }

  get modelName() {
    return this._modelName || null
  }

  set modelName(value) {
    return this._modelName = String(value || '') || null
  }

  get storeName() {
    return this._storeName || this.modelName
  }

  set storeName(value) {
    return this._storeName = String(value || '')
  }

  get data() {
    return this.state.data || []
  }

  set data(value) {
    this.state.data = value || []
    return this.data
  }

  get lastUpdated() {
    return this.state.lastUpdated
  }

  set lastUpdated(value) {
    this.state.lastUpdated = value || ''
    return this.lastUpdated
  }

  get offline() {
    return !!this.state.offline
  }

  set offline(value) {
    this.state.offline = !!value
    return this.offline
  }

  get total() {
    return this.state.total
  }

  set total(value) {
    return this.state.total = +value || 0
  }

  get mapping() {
    return {
      0: 'totals',
      1: 'records',
      2: 'deleted',
    }
  }

  register = (cb) => {
    if(this.callbacks.indexOf(cb) === -1) this.callbacks.push(cb)
  }

  unregister = (cb) => {
    let idx
    while((idx = this.callbacks.indexOf(cb)) !== -1) {
      this.callbacks.splice(idx, 1)
    }
  }

  sendCallbacks = () => this.callbacks.forEach(cb => cb(this.data, this.lastUpdated, this.offline))

  registerStream = (cb) => {
    if(this.streamCallbacks.indexOf(cb) === -1) this.streamCallbacks.push(cb)
  }

  unregisterStream = (cb) => {
    let idx
    while((idx = this.streamCallbacks.indexOf(cb)) !== -1) {
      this.streamCallbacks.splice(idx, 1)
    }
  }

  sendStreamCallbacks = (record, key) => this.streamCallbacks.forEach(cb => cb(record, key))

  transformData = record => {
    const modelSchema = (currentSchema[this.storeName] || {}).transformKeys

    if(!modelSchema) return record;

    const transformed = {}

    for(let k in modelSchema) {
      transformed[modelSchema[k]] = record[k]
    }

    return transformed
  }

  loadContent = async () => {
    if(this._loading) return this._loading

    let resolve, reject

    this._loading = new Promise((r, j) => {
      resolve = r
      reject = j
    })

    try {
      this.data = await this.getLocalData()
      this.offline = true
      this.total = this.data.length

      try {
        this.sendCallbacks()
      } catch(_) {}

      try {
        await this.getServerData()
      } catch(err) {
        this.offline = true
        console.log(err)
      }

      this._loading = false

      resolve(this.lastUpdated)

      return this.lastUpdated

    } catch(err) {
      console.log(err)

      reject(err)

      this.offline = true
      this.data = []
      this.updatedAt = ''

      throw err
    }

  }

  getLocalData = async () => {
    this.lastUpdated = false
    let resolveWrapper, rejectWrapper

    const resultProxy = new Promise((res, rej) => {
      resolveWrapper = res;
      rejectWrapper = rej;
    })

    await getAllFromDB({
      storeKey: this.storeName,
      storeCallback: (result) =>
        result
        .then(records => {
          for (let i = 0; i < records.length; i++) {
            if(
              !this.lastUpdated
              || (this.lastUpdated < records[i].updatedAt)
            ) {
              this.lastUpdated = records[i].updatedAt
            }
          }

          resolveWrapper(records)
        })
        .catch(err => rejectWrapper(err))
    })

    return await resultProxy
  }

  getServerData = async () => {
    try {
      const response = await fetch(
        `/travel/get_model_data/${this.modelName}.json?last_updated=${this.lastUpdated || ''}`,
        {
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
        }
      )

      return await this.parseServerData(response)
    } catch(err) {
      console.log(err)
      throw err
    }
  }

  parseServerData = async(response) => {
    const result = {},
          stream = new StreamJsonArray(response, (record, splitIdx) => {
            const key = this.mapping[splitIdx]
            if(key === "totals") {
              console.info(key, record)
              this.total = this.total + (record.total || 0)
              record.total = this.total
            } else if(key) record = this.transformData(record)

            if(!result[key]) result[key] = []

            result[key].push(record)
            this.sendStreamCallbacks(record, key)
          })

    await stream.promise

    return await this.handleResult(result)
  }

  handleResult = async (result) => {
    if(result.deleted) {
      await deleteFromDB({
        storeKey: this.storeName,
        records: result.deleted
      })
    }

    this.offline = !result.records || result.records.length

    if(result.records && result.records.length) {
      await saveToDB({
        storeKey: this.storeName,
        records: result.records
      })

      this.data = await this.getLocalData()

      this.offline = false

      this.sendCallbacks()
    }

    return result.records
  }
}
