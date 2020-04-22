import Cable from 'channels/cable'

const airports           = {},
      createSubscription = (airport) => new LocationSubscription(airport),
      openChannel = (code = 'LAX', callback) => {
        airports[code] = airports[code] || createSubscription(code)

        if(callback) airports[code].register(callback)

        return airports[code]
      },
      closeChannel = (code = 'LAX', callback, closeConnection = false) => {
        if(airports[code]) {
          if(callback) {
            airports[code].unregister(callback)
          } else {
            airports[code].close()
            airports[code] = null
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
      }

export default class CoachLocationChannel {
  static airports       = airports
  static openChannel    = openChannel
  static closeChannel   = closeChannel
  static connectChannel = connectChannel
}

class LocationSubscription {
  constructor(airport) {
    this.listeners = []
    this.airport = airport
    this.status = "connecting"

    this._cable = Cable.subscriptions.create(
      { channel: 'CoachLocationChannel', airport },
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

  broadcast = (eventType, data) => this.listeners.forEach(cb => cb({ airport: this.airport, eventType, data, timestamp: new Date() }))
}
