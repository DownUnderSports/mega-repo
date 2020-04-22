/* global global */

import AuthStatus from 'helpers/auth-status'

const ogFetch = fetch;

export class FetchError extends Error {
  constructor(response) {
    super(response.statusText)
    this.response = response
  }
}

export const fetchStatusHandler = function fetchStatusHandler(response) {
  if(response.type === 'opaque') return response;

  if ((response.status >= 200) && (response.status < 300)) {
    return response;
  } else {
    throw new FetchError(response);
  }
}

async function runFetch(url, options) {
  options = options || {}
  options.headers = options.headers || {}

  const currentStatus = AuthStatus.getStatus()

  if(currentStatus.dusId) options.headers['DUSID'] = currentStatus.dusId


  // const result = await ogFetch(addRandKeyToResource(url), options).then(fetchStatusHandler)

  const result = await ogFetch(url, options)

  try {
    result.headers.forEach((v, k) => {
      if(k === 'DUSID') AuthStatus.setDusId(v)
    })
    // throw new Error(' AUTH TOKEN NOT FOUND ')
  } catch (e) {
    AuthStatus.setDusId(null)
  }

  return fetchStatusHandler(result)
}

class FetchableItem {
  constructor(url, options = {}, resolve, reject) {
    this.queuedAt = new Date()
    this.key = Math.random()
    this.url = url
    this.resolve = resolve
    this.reject = reject
    this.controller = new AbortController()
    this.retried = false
    this.canceled = false
    this.options = {...(options || {}), signal: this.controller.signal, credentials: 'same-origin'}
    this.timeout = this.options.timeout || false
    this.authenticationAttempts = 0
    delete this.options.timeout
  }

  get signal() {
    return this.controller.signal
  }

  abort = () => {
    this.timeout && clearTimeout(this.timeoutFunction)

    this.canceled = true
    this.controller.abort()
  }

  controller = () => this.controller

  canAttemptAuthentication = (e) => (
    !global.clientSite &&
    !this.canceled &&
    e && e.response && (e.response.status === 401) &&
    (this.authenticationAttempts++ < 2)
  )

  runFetch = async (isRetry = false) => {
    try {
      if(this.timeout) {
        this.timeoutFunction = setTimeout(() => {
          if(!this.completedAt) {
            this.abort()
            if(!isRetry) {
              this.canceled = false
              this.controller = new AbortController()
              this.options.signal = this.controller.signal
            }
          }
        }, this.timeout)
      }
      const result = await runFetch(this.url, this.options)
      return result
    } catch (e) {
      this.timeout && clearTimeout(this.timeoutFunction)
      if(this.canAttemptAuthentication(e)) {
        this.authenticationAttempts++
        await AuthStatus.reauthenticate()
        if(AuthStatus.dusId) {
          return await this.runFetch()
        } else {
          throw e
        }
      } else {
        if(e.response && e.response.status === 401) AuthStatus.reauthenticate()
        if(isRetry || !this.timeout) {
          throw e
        }
      }
      return await this.runFetch(true)
    }
  }

  run = async () => {
    if(this.canceled) {
      this.reject('Canceled')
    } else {
      try {
        const result = await this.runFetch()
        this.resolve(result)
      } catch(e) {
        this.reject(e)
      }
    }
  }
}

// function addRandKeyToResource(url) {
//   return (String(url) + (/\?/.test(String(url)) ? '&' : '?') + 'c=' + String(Math.random()))
// }

const AuthFetch = function AuthFetch(url = '', options = {}) {
  let item,
    promise = new Promise((res, rej) => (item = new FetchableItem(url, options, res, rej)))

  promise.abort = item.abort
  promise.cancel = item.abort

  item.run()

  return promise
}

try {
  Object.defineProperty(
    global,
    'ogFetch',
    {
      get() { return ogFetch },
      set(func) { console.info("ogFetch override attempted", func) }
    }
  )

  Object.defineProperty(
    global,
    'fetch',
    {
      get() { return AuthFetch },
      set(func) { console.info("Fetch override attempted", func) }
    }
  )
} catch(e) {
  console.error(e)
  global.ogFetch = ogFetch
  global.fetch = AuthFetch
}

global.FetchError = FetchError

export default AuthFetch
