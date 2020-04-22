import Cable from 'common/js/channels/cable'

const uuids           = {},
      createSubscription = (uuid) => new ChatMessagesSubscription(uuid),
      openChannel = (uuid, callback) => {
        uuids[uuid] = uuids[uuid] || createSubscription(uuid)

        if(callback) uuids[uuid].register(callback)

        return uuids[uuid]
      },
      closeChannel = (uuid, callback) => {
        if(uuids[uuid]) {
          if(callback) {
            uuids[uuid].unregister(callback)
          } else {
            uuids[uuid].close()
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

export default class ChatMessagesChannel {
  static uuids          = uuids
  static openChannel    = openChannel
  static closeChannel   = closeChannel
  static connectChannel = connectChannel
  static disconnect     = disconnect
}

class ChatMessagesSubscription {
  constructor(uuid) {
    this.listeners = []
    this.uuid = uuid
    this.status = "connecting"

    this._cable = Cable.subscriptions.create(
      { channel: 'ChatMessagesChannel', uuid },
      {
        connected: this.onConnected,
        disconnected: this.onDisconnected,
        rejected: this.onRejected,
        received: this.onReceived,
      }
    )
    console.log(Cable)
    return this
  }

  get connected() {
    return this.status === "connected"
  }

  get rejected() {
    return this.status === "rejected"
  }

  close = () => {
    this.perform('close')
    this.onDisconnected()
    this.listeners = []

    this.unsubscribe()
  }

  unsubscribe = (...args) => {
    this._cable && this._cable.unsubscribe()
    uuids[this.uuid] = null
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
    console.log(data)
    this.broadcast("received", data)
  }

  register = (cb) => {
    if(this.listeners.indexOf(cb) === -1) this.listeners.push(cb)
    cb({ uuid: this.uuid, eventType: 'registeredListener', data: { status: this.status }, timestamp: new Date() })
  }

  unregister = (cb) => {
    let idx
    while((idx = this.listeners.indexOf(cb)) !== -1) {
      this.listeners.splice(idx, 1)
    }
    if(!this.listeners.length) this.unsubscribe()
  }

  broadcast = (eventType, data) => this.listeners.forEach(cb => cb({ uuid: this.uuid, eventType, data, timestamp: new Date() }))
}
