class RingCentral {
  activated = false
  visible = false
  isListening = false

  activate = () => {
    if(this.activated) return true
    try {
      this.activated = true
      const rcs = document.createElement("script")
      // if(process.env.NODE_ENV === "development") {
      //   rcs.src = "https://ringcentral.github.io/ringcentral-embeddable/adapter.js?clientId=9FE0ZQ1GQySQs9YeE1_4_Q&appServer=https://platform.devtest.ringcentral.com";
      // } else {
      rcs.src = "https://ringcentral.github.io/ringcentral-embeddable/adapter.js?clientId=qv01G46hTfK4V3ygrrt3ug";
      // }

      this.setDocumentObserver()
      document.body.appendChild(rcs);
    } catch(err) {
      console.error(err)
      this.activated = false
      this.addButton()
    }
    return this.activated
  }

  addStorageListener = () => {
    window.addEventListener('storage', this.onStorage)
  }

  removeStorageListener = () => {
    try {
      window.removeEventListener('storage', this.onStorage)
    } catch(_) {}
  }

  setDocumentObserver = () => {
    // select the target node
    if(this.widgetEl) {
      this.setMutationObserver()
    } else {
      // create an observer instance
      const observer = new MutationObserver((mutations) => {
          if(this.widgetEl) {
            observer.disconnect()
            return this.setMutationObserver()
          }
          mutations.forEach(function(mutation) {
            console.log(mutation)
          });
      });

      // configuration of the observer:
      var config = { attributes: true, childList: true, characterData: true }

      // pass in the target node, as well as the observer options
      observer.observe(document.body, config);
    }
  }

  // widgetMutated = (mutations) => this.setVisible()

  setMutationObserver = () => {
    if(this.mutationObserver) return false
    else {
      this.mutationObserver = new MutationObserver(this.setVisible)
      this.mutationObserver.observe(this.widgetEl, { attributes: true, childList: true, characterData: true })
      this.toggleButton.addEventListener("click", this.toggleVisible)
      this.addButton()
      this.setVisible()
    }
  }

  setVisible = () => {
    if(!this.visible && !this.widgetEl.classList.contains("Adapter_minimized")) {
      this.widgetEl.classList.add("Adapter_minimized")
      this.toggleButton.click()
    } else if(this.visible && this.widgetEl.classList.contains("Adapter_minimized")) {
      this.widgetEl.classList.remove("Adapter_minimized")
      this.toggleButton.click()
    }
  }

  toggleVisible = e => {
    if(Math.abs(e.clientX - this.toggleButton.getBoundingClientRect().x) < 20) {
      this.visible = !this.visible
      this.setVisible()
    }
  }

  queryWindows = () => {
    clearTimeout(this.addListener)
    const activeTime = localStorage.getItem('activeCallListener')
    if(!activeTime || (new Date(+activeTime) < new Date(new Date() - (12 * 60 * 60)))) {
      localStorage.setItem('getActiveCallListener', Date.now())
      this.addListener = setTimeout(this.setListener, Math.floor(Math.random() * 1000) + 250)
    }
  }

  setListener = () => {
    this.isListening = true
    this.notify()
    window.addEventListener('message', this.onMessage)
    window.addEventListener('beforeunload', this.onWindowClose)
  }

  unsetListener = () => {
    this.isListening = false
    try {
      localStorage.removeItem('activeCallListener')
      window.removeEventListener('message', this.onMessage)
      window.removeEventListener('beforeunload', this.onWindowClose)
    } catch(_) {}
  }

  notify = () => localStorage.setItem('activeCallListener', Date.now())

  addButton = () => this.button.style.display = 'block'

  removeButton = () => this.button.style.display = 'none'

  onMessage = (event) => {
    const data  = event.data || {}
    switch (data.type) {
      case "rc-active-call-notify":
        const { telephonyStatus, direction, from = {} } = data.call || {},
              isInboundCall = (telephonyStatus === "CallConnected") && (direction === "Inbound")
        if(isInboundCall && (process.env.NODE_ENV !== "development")) {
          const number = from.phoneNumber.replace(/^\+1/, ''),
                windowName = `_inbound_call_${number}`
          if(number.length < 10) return false
          if(window.name !== windowName){
            const w = window.open('', windowName)
            // w.name = `_inbound_call_${number}`
            // w.opener = null
            // w.referrer = null
            w.location = `${window.location.origin}/admin/users?phone=${number}`
          }
        }
        break;
      case "rc-login-status-notify":
        setTimeout(this.setCallAvailable, 1000)
        break;
      default:
        if(window.logRingCentralEvents) console.log(data, event)
    }
  }

  onStorage = (event) => {
    console.log("ON STORAGE")
    console.log(event.key)
    if (event.key === 'getActiveCallListener') {
      if(this.isListening) this.notify()
    } else if (event.key === 'activeCallListener') {
      clearTimeout(this.addListener)
    } else if (event.key === 'callListenerRemoved') {
      this.queryWindows()
    } else if(event.key === 'resetCallListener') {
      this.unsetListener()
    }
  }

  onWindowClose = () => {
    this.isListening = false
    this.removeStorageListener()
    localStorage.removeItem('activeCallListener')
    localStorage.setItem('callListenerRemoved', Date.now())
  }

  unhide() {
    document.body.classList.add('show-ring-central')
  }

  resetStorage = () => {
    localStorage.setItem('resetCallListener', Date.now())

    this.unsetListener()
    window.location.reload()
  }

  swapPhoneType = () =>
    this.frame && this.frame.contentWindow.postMessage({
      type: 'rc-calling-settings-update',
      callWith: 'otherphone',
      // myLocation: '+1111111111', // required for myphone and customphone
      ringoutPrompt: false, // required for myphone and customphone,
      // fromNumber: '+1111111111', // set from number when callWith is browser
    }, '*')

  setCallAvailable = async () => {
    await this.getFrame()
    //toggle off first otherwise it doesn't set accept queue calls
    this.frame.contentWindow.postMessage({
      type: 'rc-adapter-presenceItemClicked',
      presenceType: 'DoNotAcceptAnyCalls', // Available, Busy, DoNotAcceptAnyCalls, Offline
    }, '*');

    //Push Next Tick and toggle presence
    setTimeout(() => {
      this.frame.contentWindow.postMessage({
        type: 'rc-adapter-presenceItemClicked',
        presenceType: 'TakeAllCalls', // Available, Busy, DoNotAcceptAnyCalls, Offline
      }, '*');
    }, 1000)
  }

  getFrame = async resolve => {
    if(!resolve) return await new Promise(r => { this.getFrame(r) })
    else if(this.frame) return resolve(this.frame)
    else return setTimeout(() => { this.getFrame(resolve) }, 100)
  }

  get widgetEl() {
    return this._widgetEl = this._widgetEl || document.getElementById('rc-widget')
  }

  get toggleButton() {
    return this._toggleButton = this._toggleButton || (this._widgetEl && this.widgetEl.querySelector('.Adapter_toggle'))
  }

  get id() {
    return this._id = this._id || `activate-ring-central-${String(Math.random()).replace('0.', '')}`
  }

  get button() {
    if(this._button) return this._button
    this.button = document.getElementById(this.id) || document.createElement("BUTTON")
    this.widgetEl.appendChild(this._button);
    return this._button
  }

  get frame() {
    return this._frame = this._frame || (this.widgetEl && this.widgetEl.querySelector('iframe#rc-widget-adapter-frame'))
  }

  set button(element) {
    this._button = element
    this._button.id = this.id
    this._button.innerHTML = 'Fix Call Lookup'
    this._button.classList.add('btn')
    this._button.classList.add('btn-warning')
    this._button.classList.add('btn-sm')
    this._button.classList.add('ringcentral-reset-button')
    this._button.style.position = 'fixed'
    this._button.style.zIndex = '1000'
    this._button.style.bottom = '.5rem'
    this._button.style.right = '.5rem'
    this._button.style.fontSize = '.5rem'
    this._button.addEventListener('click', this.resetStorage)
    return this._button
  }

  constructor() {
    console.log(window.name)
    this.addStorageListener()
    this.queryWindows()
    // if(localStorage.getItem('show-ring-central')) this.unhide()
    // else this.addButton()
  }
}

const ringCentralManager = new RingCentral()
setTimeout(ringCentralManager.activate, 2000)

export default ringCentralManager
