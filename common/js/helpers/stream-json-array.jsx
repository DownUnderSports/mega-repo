export default class StreamJsonArray {
  constructor(response, cb, userOptions) {
    const { cancel, close, ...options} = userOptions || {}

    this._currentString = ''

    this.reader = response.body.getReader()
    this.options = options || {}

    this.value = [[]]
    this.index = 0
    this.callback = cb || this.logValue

    let resolve, reject

    this.promise = new Promise((r,j) => {
      resolve = r
      reject  = j
    })

    this.resolve = resolve
    this.reject = reject

    this.stream()

    return this
  }

  logValue = (row) => {
    console.log(row, this.index)
  }

  stream = async () => {
    const { done, value } = await this.read()

    // When no more data needs to be consumed, close the stream
    if (done) {
      return this.close();
    }

    let v = new TextDecoder("utf-8").decode(value)

    if(!this._currentString) v = v.replace(/^\s*/m, '')

    // Enqueue the next data chunk into our target stream
    this.enqueue(v);
    return this.stream();
  }

  enqueue = (value) => {
    try {
      value = String((this._currentString || '') + (value || ''))

      if(/--JSON--SPLIT--ARRAY--/.test(value)) {
        value = value.replace(/\s*--JSON--SPLIT--ARRAY--\s*/g, '--JSON--SPLIT--ARRAY--').split('--JSON--SPLIT--ARRAY--')
        for(let i = 0; i < value.length; i++) {
          if(value[i]) {
            if(i) this.index++
            this.enqueue(value[i])
            this.pushCurrent()
          }
        }
        return this.value
      }


      if(/\}[^}{]*\{/g.test(value)) {
        const t = `####${new Date().toJSON()}####`

        value = value.replace(/\}[^}{]*\{/g, `}${t}{`).split(t)

        this._currentString = value[value.length - 1] || ''

        for(let i = 0; i < (value.length - 1); i++) {
          if(/\}[^}{]*\{/g.test(value[i])) console.log(value[i], value)
          try {
            this.pushValue(value[i])
          } catch (err) {
            console.log(err)
            console.log(value[i])
          }
        }
      } else {
        this._currentString = String(value || '')
      }
    } catch (err) {
      console.log(err)
      console.log(value)
    }
  }

  read = () => this.reader.read()

  close = () => {
    this.pushCurrent()
    return this.resolve(this.value)
  }

  cancel = () => {
    try {
      this.reader.cancel()
      throw new Error('JSON Stream Canceled')
    } catch(err) {
      return this.reject(err)
    }
  }

  pushValue = (value) => {
    value = JSON.parse(value)
    if(!this.value[this.index]) this.value[this.index] = []
    this.value[this.index].push(value)
    this.callback(value, this.index)
  }

  pushCurrent = () => {
    if(this._currentString) this.pushValue(this._currentString)

    this._currentString = ''
  }
}
