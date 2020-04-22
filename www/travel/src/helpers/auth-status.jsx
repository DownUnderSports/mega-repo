/* global global */

const callbacks = []

class AuthStatusWrapper {
  // static authTokenName = 'DusAuthToken'

  get dusId() {
    return this._dusIdValue || ''
  }

  set dusId(value) {
    if(value === "undefined" || value === "false" || !value) {
      value = ''
    }
    if(this._dusIdValue !== value) {
      this._dusIdValue = value
      localStorage.setItem(this.authTokenName, this.dusId);
      this.broadcast()
    }
    return this._dusIdValue
  }

  get headerHash() {
    return this.dusId ? { DUSID: this.dusId } : {}
  }

  constructor(values = {}) {
    global.addEventListener('storage', this.onStorage)
    this.dusId = values.dusId || this.getDusId()
    this.validated = !!values.validated
    this.stayLoggedIn = !!values.stayLoggedIn
    this.authTokenName = values.authTokenName || 'TravelDusIDToken'
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
    if(this.dusId) return res()
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
        if(!this.dusId) {
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

      this.getDusId()
      setTimeout(this.sendToServer, 750)
    }
  }

  sendToServer = async () => {
    localStorage.removeItem('Authenticating')
    this.dispatchUpdate()
  }

  // receiveFromServer = (ev) => {
  //   global.removeEventListener('message', this.receiveFromServer, false)
  //   this.dusId = ev.data
  // }

  getStatus = () => ({
    dusId: this.dusId,
    validated: this.validated
  })

  getDusId = () => (
    this.getFromPage() ||
    this.getFromStorage() ||
    this.queryWindows()
    // this.getFromStorage() ||
    // this.getFromCookie()
  )

  getFromPage = () => {
    if(this._retreivedHTML) return false
    this._retreivedHTML = true
    this.dusId = (document.getElementById('loaded_dus_id') || {}).value
    return this.dusId
  }

  getFromStorage = () => {
    try {
      this.dusId = localStorage.getItem(this.authTokenName) || false;
    } catch (e) {
      this.dusId = false
      this.setPermissions()
    }
    return this.dusId;
  }

  onStorage = (event) => {
    const dusIdWas = this.dusId
    if (event.key === this.authTokenName) {
      event.preventDefault()
      event.stopPropagation()

      this.dusId = event.newValue
    } else if (this.dusId && (event.key === `get${this.authTokenName}`)) {
      event.preventDefault()
      event.stopPropagation()

      localStorage.setItem(this.authTokenName, this.dusId);
    }

    (this.dusId !== dusIdWas) && this.dispatchUpdate()
  }

  reauthenticate = async () => {
    this.dusId = false
  }

  queryWindows = () => {
    localStorage.setItem(`get${this.authTokenName}`, Date.now())
  }

  setDusId = (value) => this.dusId = value

  setPermissions = ({...permissions}) => {
    this.permissions = permissions || {}
  }
}

const AuthStatus =  new AuthStatusWrapper()

export default AuthStatus
