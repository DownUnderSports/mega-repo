/* global global */
import ActionCable from 'actioncable'

const { host, protocol } = global.location

export const WS_ROOT = `${String(protocol || '').replace(/http/g, 'ws')}//${host}/cable`

export const WS_HEADERS = {
  Accept: 'application/json',
  'Content-Type': 'application/json',
}

let cable

export default class Cable {
  static get connection() {
    return this.consumer.connection
  }

  static get consumer() {
    return cable = cable || ActionCable.createConsumer(WS_ROOT)
  }

  static reconnect() {
    this.disconnect()
    return this.consumer
  }

  static disconnect() {
    this.consumer.disconnect()
    cable = null
  }

  static get subscriptions () {
    return this.consumer.subscriptions
  }

  static get url() {
    return this.consumer.url
  }
}
