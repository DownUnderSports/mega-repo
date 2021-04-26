import FetchQueue from 'common/js/helpers/fetch-queue'
import { pxyPort } from 'common/js/helpers/proxy-port'

const callbacks = []

let email, password

class AuthStatusWrapper {
  // static authTokenName = 'DusAuthToken'

  get token() {
    return this._tokenValue || ''
  }

  get authenticationProven() {
    return !!this._authenticationProven
  }

  set authenticationProven(value) {
    this._authenticationProven = !!value
  }

  set token(value) {
    if(value === "undefined" || value === "false" || !value) {
      value = ''
    }
    if(this._tokenValue !== value) {
      this._tokenValue = value
      sessionStorage.setItem(this.authTokenName, value)
    }
    return this._tokenValue
  }

  get headerHash() {
    return this.token ? { Authorization: 'Bearer ' + this.token } : {}
  }

  constructor(values = {}) {
    window.addEventListener('storage', this.onStorage)
    this.token = values.token || this.getToken()
    this.validated = !!values.validated
    this.stayLoggedIn = !!values.stayLoggedIn
    this.authTokenName = AuthStatusWrapper.authTokenName || 'DusAuthToken'
    this.listeningFor = []
    this.isListening = false
  }

  _getCookies = async () => {
    try {
      return await fetch('/no_op')
    } catch(e) {
      return false
    }
  }

  dispatchUpdate = () => {
    window.document.dispatchEvent(new CustomEvent(
      'authStatusChange',
      {
        detail: undefined,
        bubbles: true,
        cancelable: false,
      }
    ))
    this.broadcast()
  }

  subscribeAndCall = (cb) => {
    this.subscribe(cb)
    cb(this.getStatus())
  }
  subscribe = (cb) => (callbacks.indexOf(cb) === -1) ? callbacks.push(cb) : cb

  unsubscribe = (cb) => {
    let idx
    while((idx = callbacks.indexOf(cb)) !== -1) {
      callbacks.splice(idx, 1)
    }
  }

  broadcast = () => callbacks.forEach(cb => cb(this.getStatus()))

  available = () => new Promise((res) => {
    if(this.token) return res()
    this.listeningFor.push(res)
    this.setAuthWaitingTimeout()
    this.listen()
  })

  setAuthWaitingTimeout = () => {
    if(
      !this.waitingForAuthTimeout
      && !FetchQueue.runningCount
      && localStorage.getItem('Authenticating')
    ) {
      this.waitingForAuthTimeout = setTimeout(() => {
        this.waitingForAuthTimeout = false
        if(!this.token && !FetchQueue.runningCount) {
          localStorage.removeItem('Authenticating')
          this.authenticate()
        }
      }, 5000)
    }
  }

  listen = () => {
    if(!this.isListening) {
      this.isListening = true
      window.document.addEventListener('authStatusChange', this.changeListener)
      this.authenticate()
    }
  }

  changeListener = (e) => {
    if(this.token) {
      clearTimeout(this.waitingForAuthTimeout)
      this.waitingForAuthTimeout = false
      window.document.removeEventListener('authStatusChange', this.changeListener)
      this.isListening = false
      const arr = this.listeningFor
      this.listeningFor = []
      arr.map((r) => r())
    }
  }

  authenticate = () => {
    if(!localStorage.getItem('Authenticating')) {
      localStorage.setItem('Authenticating', true)

      window.addEventListener('beforeunload', () => localStorage.removeItem('Authenticating'))

      // this.sendToServer()

      this.queryWindows()

      setTimeout(this.sendToServer, 750)
    }
  }

  sendToServer = async () => {
    if(!this.token) {
      console.log(process.env.REACT_APP_AUTH_URL, pxyPort, String(process.env.REACT_APP_AUTH_URL || '').replace('%LOCAL_PORT%', String(pxyPort || 443)))

      // const url = String(process.env.REACT_APP_AUTH_URL || '').replace('%LOCAL_PORT%', String(pxyPort || 443)),
      const url = "/admin/sessions.json",
            deviceId = url && document.getElementById('device-id'),
            value = url && `${url}?${deviceId ? `device_id=${deviceId.value}` : ''}`

      if(value) {
        // window.addEventListener('message', this.receiveFromServer, false)
        try {
          email = process.env.REACT_APP_PERMANENT_LOGIN_EMAIL || email || window.prompt("Please enter your email", localStorage.getItem('window-auth-email') || "mail@downundersports.com");
          localStorage.setItem('window-auth-email', email)
          password = process.env.REACT_APP_PERMANENT_LOGIN_PASSWORD || password || window.prompt("Please enter your password", sessionStorage.getItem('window-auth-password') || "");
          sessionStorage.setItem('window-auth-password', password)

          const result = await fetch(value, {
                  method: "POST",
                  skipQueue: true,
                  mode: 'cors',
                  connection: 'close',
                  headers: {
                    "Content-Type": "application/json; charset=utf-8"
                  },
                  body: JSON.stringify({ email, password })
                }),
                json = await result.json()
          this.authenticationProven = deviceId || (process.env.NODE_ENV === "development")
          this.token = json.token
          await this._getCookies()
        } catch(e) {
          email = null
          password = null
          this.token = null
        }
      }
    }
    localStorage.removeItem('Authenticating')
    localStorage.setItem('tokenOverride', this.token)
    this.dispatchUpdate()
  }

  // receiveFromServer = (ev) => {
  //   window.removeEventListener('message', this.receiveFromServer, false)
  //   this.token = ev.data
  // }

  getStatus = () => ({
    token: this.token,
    validated: this.validated
  })

  getToken = () => (
    this.getFromSessionStorage() ||
    this.queryWindows()
    // this.getFromStorage() ||
    // this.getFromCookie()
  )

  // getFromStorage = () => {
  //   this.authenticationProven = false
  //
  //   try {
  //     this.token = localStorage.getItem(this.authTokenName) || false;
  //   } catch (e) {
  //     this.token = false
  //     this.setPermissions()
  //   }
  //   return this.token;
  // }

  getFromSessionStorage = () => {
    this.authenticationProven = false
    try {
      this.token = sessionStorage.getItem(this.authTokenName) || false;
    } catch (e) {
      this.token = false
      this.setPermissions()
    }
    return this.token;
  }
  //
  // getFromCookie = () => {
  //   this.token = false
  //
  //   try {
  //     const nameEQ = this.authTokenName + "=",
  //           ca = document.cookie.split(';');
  //
  //     for(let i = 0; i < ca.length; i++) {
  //       let c = ca[i];
  //       while (c.charAt(0) === ' ') c = c.substring(1,c.length);
  //       if (c.indexOf(nameEQ) === 0) this.token = c.substring(nameEQ.length,c.length);
  //     }
  //
  //     if(!this.token) throw new Error('Cookie Not Found');
  //   } catch(e) {
  //     this.token = false
  //     this.setPermissions()
  //   }
  // }

  onStorage = (event) => {
    const tokenWas = this.token
    if (event.key === 'tokenOverride') {
      this.token = event.newValue
    } else if (this.token && (event.key === 'getSessionStorage')) {
      event.preventDefault()
      event.stopPropagation()

      localStorage.setItem('sessionStorage', JSON.stringify(sessionStorage));
      setTimeout( () => {
        localStorage.removeItem('sessionStorage');
      }, 100)

    } else if (event.key === 'sessionStorage' && !this.token) {
      event.preventDefault()
      event.stopPropagation()

      const data = JSON.parse(event.newValue) || {};

      this.authenticationProven = false

      this.token = data[this.authTokenName]
    }

    (this.token !== tokenWas) && this.dispatchUpdate()
  }

  reauthenticate = async () => {
    await (
      this._reauthenticate = this._reauthenticate || (new Promise(async (r,j) => {
        this.token = false
        this.authenticationProven = false

        try {
          await this.sendToServer()
          await this._getCookies()
          r(this._reauthenticate = null)
        } catch(err) {
          this.token = false
          this.authenticationProven = false
          this._reauthenticate = null
          j(err)
        }
      }))
    )
  }

  queryWindows = () => {
    localStorage.setItem('getSessionStorage', Date.now())
  }

  // setCookie = ({value, days, hours}) => {
  //   var expires = "";
  //   if (days || hours) {
  //     var date = new Date(),
  //         multiplier = hours ? (hours*60*60*1000) : (days*24*60*60*1000);
  //
  //     date.setTime(date.getTime() + multiplier);
  //     expires = "; expires=" + date.toUTCString();
  //   }
  //   document.cookie = this.authTokenName + "=" + (value || "")  + expires + "; path=/";
  // }

  // eraseCookie = () => {
  //   document.cookie = this.authTokenName + '=; Max-Age=-99999999;';
  //   this.token = false;
  // }

  setToken = (value) => this.token = value

  setPermissions = ({...permissions}) => {
    this.permissions = permissions || {}
  }
}

const AuthStatus =  new AuthStatusWrapper()

export default AuthStatus
