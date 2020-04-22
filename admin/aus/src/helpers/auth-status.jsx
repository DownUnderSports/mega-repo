/* global global */

const callbacks = []

class AuthStatusWrapper {
  // static authTokenName = 'DusAuthToken'

  get token() {
    return this._tokenValue || ''
  }

  set token(value) {
    if(value === "undefined" || value === "false" || !value) {
      value = ''
    }
    if(this._tokenValue !== value) {
      this._tokenValue = value
      this.dispatchUpdate()
      this.broadcast()
    }
    return this._tokenValue
  }

  get dusId() {
    return this._dusIdValue || ''
  }

  set dusId(value) {
    if(value === "undefined" || value === "false" || !value) {
      value = ''
    }
    if(this._dusIdValue !== value) {
      this._dusIdValue = value
      localStorage.setItem(this.dusIdAuthTokenName, this.dusId);
      this.dispatchUpdate()
      this.broadcast()
    }
    return this._dusIdValue
  }

  get headerHash() {
    return this.token ? { Authorization: 'Bearer ' + this.token, DUSID: this.dusId } : { DUSID: this.dusId }
  }

  constructor(values = {}) {
    global.addEventListener('storage', this.onStorage)
    this.token = values.token || this.getToken()
    this.validated = !!values.validated
    this.stayLoggedIn = !!values.stayLoggedIn
    this.authTokenName = values.authTokenName || 'DusAuthToken'
    this.dusIdAuthTokenName = `${this.authTokenName}DusID`
    this.listeningFor = []
    this.isListening = false
  }

  dispatchUpdate = () => global.document.dispatchEvent(new CustomEvent(
    'authStatusChange',
    {
      detail: undefined,
      bubbles: true,
      cancelable: false,
    }
  ))

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
      && localStorage.getItem('Authenticating')
    ) {
      this.waitingForAuthTimeout = setTimeout(() => {
        this.waitingForAuthTimeout = false
        if(!this.token) {
          localStorage.removeItem('Authenticating')
          this.authenticate()
        }
      }, 5000)
    }
  }

  listen = () => {
    if(!this.isListening) {
      this.isListening = true
      global.document.addEventListener('authStatusChange', this.changeListener)
      this.authenticate()
    }
  }

  changeListener = (e) => {
    clearTimeout(this.waitingForAuthTimeout)
    this.waitingForAuthTimeout = false
    global.document.removeEventListener('authStatusChange', this.changeListener)
    this.isListening = false
    const arr = this.listeningFor
    this.listeningFor = []
    arr.map((r) => r())
  }

  authenticate = () => {
    if(!localStorage.getItem('Authenticating')) {
      localStorage.setItem('Authenticating', true)

      global.addEventListener('beforeunload', () => localStorage.removeItem('Authenticating'))

      // this.sendToServer()

      this.queryWindows()

      setTimeout(this.sendToServer, 750)

    }
  }

  sendToServer = async () => {
    if(!this.token) {

      const el = document.getElementById('dus_auth_url')
      let value = el && el.value

      if(!value) {
        try {
          const result = await fetch('/admin/whats_my_url')
          value = await result.text()
        } catch (err) {
          console.log(err)
        }
      }

      if(value) {
        // global.addEventListener('message', this.receiveFromServer, false)
        try {
          const result = await fetch(value.replace(/:(\d)200(\/|\?|$)/, ":$1100$2"), {
                  skipQueue: true,
                  mode: 'cors',
                  connection: 'close',
                  headers: {
                    "Content-Type": "application/json; charset=utf-8"
                  }
                }),
                json = await result.json()

          this.token = json.token
          this.dusId = json.id
        } catch(e) {
          this.token = null
        }
      }
    }
    localStorage.removeItem('Authenticating')
    localStorage.setItem('tokenOverride', this.token)
    this.dispatchUpdate()
  }

  // receiveFromServer = (ev) => {
  //   global.removeEventListener('message', this.receiveFromServer, false)
  //   this.token = ev.data
  // }

  getStatus = () => ({
    dusId: this.dusId,
    token: this.token,
    validated: this.validated
  })

  getToken = () => (
    this.getFromSessionStorage() ||
    this.queryWindows()
    // this.getFromStorage() ||
    // this.getFromCookie()
  )

  getFromStorage = () => {
    try {
      this.token = localStorage.getItem(this.authTokenName) || false;
    } catch (e) {
      this.token = false
      this.setPermissions()
    }
    return this.token;
  }

  getFromSessionStorage = () => {
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

      this.token = data[this.authTokenName]
    }

    (this.token !== tokenWas) && this.dispatchUpdate()
  }

  reauthenticate = async () => {
    this.token = false
    await this.sendToServer()
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
