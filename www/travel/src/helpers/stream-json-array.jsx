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

  delimitter = (value) => {
    this._delimitterString = (this._delimitterString || '') + value
    const matchArray = /!!-->>.*?<<--!!/.test(this._delimitterString)
    if(matchArray) {
      this._parser = new RegExp(`}${matchArray[1]}{`.replace(/[-[\]{}()*+!<=:?./\\^$|#\s,]/g, '\\$&', 'g'))
      this._isParsing = false
      value = this._delimitterString.replace(/!!-->>.*?<<--!!/, '')
      this._delimitterString = ''
      this.enqueue(value)
    }
  }

  enqueue = (value) => {
    try {
      value = String((this._currentString || '') + (value || ''))
      this._currentString = ''

      if(!this._parsedOptions) {
        this._parsedOptions = true

        if(/^!/.test(value)) {
          this._isParsing = true

          return this.delimitter(value, true)
        } else {
          this._parser = /\}[\r\n\s]*\{/g
        }

      } else if(this._isParsing) {
        return this.delimitter(value)
      }

      if(/--JSON--SPLIT--ARRAY--/.test(value)) {
        value = value.replace(/\s*--JSON--SPLIT--ARRAY--\s*/g, '--JSON--SPLIT--ARRAY--').split('--JSON--SPLIT--ARRAY--')
        for(let i = 0; i < value.length; i++) {
          if(i) {
            this.pushCurrent()
            this.index++
          }

          this.enqueue(value[i])
        }
        return this.value
      }


      if(this._parser.test(value)) {
        const t = `####${new Date().toJSON()}####`

        value = value.replace(this._parser, `}${t}{`).split(t)

        this._currentString = value[value.length - 1] || ''

        for(let i = 0; i < (value.length - 1); i++) {
          try {
            this.pushValue(value[i])
          } catch (err) {
            console.log(value[i])
            throw err
          }
        }
      } else {
        this._currentString = String(value || '')
      }
    } catch (err) {
      console.log(value)
      this.raiseError(err)
    }
  }

  read = () => this.reader.read()

  close = () => {
    this.pushCurrent()
    return this.resolve(this.value)
  }

  cancel = () => {
    try {
      throw new Error('JSON Stream Canceled')
    } catch(err) {
      this.raiseError(err)
    }
  }

  raiseError = (err) => {
    console.log(err)
    try {
      this.reader.cancel()
    } catch(_) {}
    return this.reject(err)
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
