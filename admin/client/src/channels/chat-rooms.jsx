import Cable from 'common/js/channels/cable'

const subscriptionInfo   = {},
      openChannel = (callback) => {
        subscriptionInfo.channel = subscriptionInfo.channel || new ChatRoomsSubscription()

        if(callback) {
          subscriptionInfo.channel.register(callback)
          callback({ eventType: "initial", data: { status: subscriptionInfo.channel.status }, timestamp: new Date() })
        }

        // if(callback) subscriptionInfo.channel.register(callback)

        return subscriptionInfo.channel
      },
      closeChannel = (callback) => {
        if(subscriptionInfo.channel) {
          if(callback) {
            subscriptionInfo.channel.unregister(callback)
          } else {
            subscriptionInfo.channel.close()
            subscriptionInfo.channel = null
          }
        }
      },
      connectChannel = async (...args) => {
        const channel = openChannel(...args)
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
      },
      disconnect  = () => {
        closeChannel()
        Cable.disconnect()
      }

export default class ChatRoomsChannel {
  static subscriptionInfo = subscriptionInfo
  static openChannel      = openChannel
  static closeChannel     = closeChannel
  static connectChannel   = connectChannel
  static disconnect       = disconnect
}

class ChatRoomsSubscription {
  constructor() {
    this.listeners = []
    this.status = "connecting"

    this._cable = Cable.subscriptions.create(
      { channel: 'ChatRoomsChannel' },
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
    this.onDisconnected()
    this._cable.unsubscribe()
  }

  perform = (...args) => {
    this._cable.perform(...args)
  }

  onStatusChange = (status, value) => {
    this.status = status
    this.broadcast(status, { status, value, statusChange: true })
  }

  onConnected = () => {
    this.onStatusChange("connected")
  }

  onDisconnected = (value) => {
    this.onStatusChange("disconnected", value)
  }

  onRejected = () => {
    this.onStatusChange("rejected")
  }

  onReceived = (data) => {
    this.broadcast("received", data)
  }

  register = (cb) => {
    if(this.listeners.indexOf(cb) === -1) this.listeners.push(cb)
    cb({ eventType: 'registeredListener', data: { status: this.status }, timestamp: new Date() })
  }

  unregister = (cb) => {
    let idx
    while((idx = this.listeners.indexOf(cb)) !== -1) {
      this.listeners.splice(idx, 1)
    }
  }

  broadcast = (eventType, data) => this.listeners.forEach(cb => cb({ eventType, data, timestamp: new Date() }))
}
