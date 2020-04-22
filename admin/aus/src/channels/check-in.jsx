import Cable from 'channels/cable'
let subscription = null
const openChannel = (callback) => {
        subscription = subscription || new CheckInSubscription()

        if(callback) subscription.register(callback)

        return subscription
      },
      closeChannel = (callback) => {
        if(subscription) {
          if(callback) {
            subscription.unregister(callback)
          } else {
            subscription.close()
            subscription = null
          }
        }
      },
      connectChannel = async (callback) => {
        const channel = openChannel(callback)
        if(channel.rejected) throw new Error('Websocket Connection Rejected')
        if(channel.connected) return channel
        return await new Promise((r, j) => {
          let func
          func = (data) => {
            switch (data.event) {
              case "connected":
                r(data)
                break;
              case "rejected":
                j(data)
                break;
              default:
                return console.log(data)
            }
            channel.unregister(func)
          }
          channel.register(func)
        })
      }

export default class CheckInChannel {
  static openChannel    = openChannel
  static closeChannel   = closeChannel
  static connectChannel = connectChannel
}

class CheckInSubscription {
  constructor() {
    this.listeners = []
    this.status = "connecting"

    this._cable = Cable.subscriptions.create(
      { channel: 'CheckInChannel' },
      {
        connected: this.onConnected,
        disconnected: this.onDisconnected,
        rejected: this.onRejected,
        received: this.onReceived,
      }
    )
    return this
  }

  get connected() {
    return this.status === "connected"
  }

  get rejected() {
    return this.status === "rejected"
  }

  close = () => {
    this._cable.unsubscribe()
  }

  perform = (...args) => {
    this._cable.perform(...args)
  }

  onStatusChange = (status, data) => {
    this.status = status
    console.log(status, data)
    this.broadcast(status, data)
  }

  onConnected = (...args) => {
    this.onStatusChange("connected", args)
  }

  onDisconnected = (value) => {
    this.onStatusChange("disconnected", value)
  }

  onRejected = (...args) => {
    this.onStatusChange("rejected", args)
  }

  onReceived = (data) => {
    this.broadcast("received", data)
  }

  register = (cb) => {
    if(this.listeners.indexOf(cb) === -1) this.listeners.push(cb)
    cb({ eventType: 'registeredStatus', data: this.status, timestamp: new Date() })
  }

  unregister = (cb) => {
    let idx
    while((idx = this.listeners.indexOf(cb)) !== -1) {
      this.listeners.splice(idx, 1)
    }
  }

  broadcast = (eventType, data) => this.listeners.forEach(cb => cb({ eventType, data, timestamp: new Date() }))
}
