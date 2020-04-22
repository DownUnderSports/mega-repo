import AuthStatus from 'common/js/helpers/auth-status'
import FetchQueue from 'common/js/helpers/fetch-queue'
import canUseDOM from 'common/js/helpers/can-use-dom'

var ogFetch = fetch;

export class FetchError extends Error {
  constructor(response) {
    super(response.statusText)
    this.response = response
  }
}

export const fetchStatusHandler = function fetchStatusHandler(response) {
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

  if(currentStatus.token) {
    options.headers['Authorization'] = 'Bearer ' + (currentStatus.token || '')
  } else {
    delete options.headers['Authorization']
  }


  // const result = await ogFetch(addRandKeyToResource(url), options).then(fetchStatusHandler)

  const result = await ogFetch(url, options)

  try {
    result.headers.forEach((v, k) => {
      if(k === 'auth_token') AuthStatus.setToken(v)
    })
    // throw new Error(' AUTH TOKEN NOT FOUND ')
  } catch (e) {
    AuthStatus.setToken(null)
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
    delete this.options.skipQueue
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
    !window.clientSite &&
    !this.canceled &&
    e && e.response && (e.response.status === 401) &&
    (this.authenticationAttempts++ < 3)
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
        if(AuthStatus.token) {
          return await this.runFetch()
        } else {
          throw e
        }
      } else {
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
    skipQueue = !!options.skipQueue,
    promise = new Promise((res, rej) => (item = new FetchableItem(url, options, res, rej)))

  promise.abort = item.abort
  promise.cancel = item.abort

  FetchQueue[skipQueue ? 'nextItem' : 'push'](item)

  return promise
}

if(canUseDOM) {
  try {
    Object.defineProperty(
      window,
      'fetch',
      {
        get() { return AuthFetch },
        set(func) { console.info("Fetch override attempted", func) }
      }
    )
  } catch(e) {
    console.error(e)
    window.fetch = AuthFetch
  }
  window.FetchError = FetchError
}

export default AuthFetch
