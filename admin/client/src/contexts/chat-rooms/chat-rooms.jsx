import React, {createContext, Component} from 'react'
import ChatRoomsChannel from 'channels/chat-rooms'
import AuthStatus from 'common/js/helpers/auth-status'

export const ChatRooms = {}

// Notification.onclick = (event) => {
//   console.info(event)
//   window.open("https://admin.downundersports.com/chat", '_chat')
// }

ChatRooms.DefaultValues = {
  error: false,
  rooms: [],
  cache: {},
  online_staff: {},
  available: false,
  latestView: new Date(+(localStorage.getItem("chat-room-latest-view") || 0)),
  latestMessage: null,
  loading: true,
  open: false,
  toggled_by: ''
}

ChatRooms.Context = createContext(ChatRooms.DefaultValues)

ChatRooms.Decorator = function withChatRoomsContext(Component) {
  return (props) => (
    <ChatRooms.Context.Consumer>
      {chatRoomProps => <Component {...props} chatRoomContext={chatRoomProps} />}
    </ChatRooms.Context.Consumer>
  )
}

export default class ReduxChatRoomsProvider extends Component {
  constructor(props) {
    super(props)
    this.state = {
      ...ChatRooms.DefaultValues,
      onView: this._roomViewed,
      ping: this._checkForUpdates,
      toggleAvailability: this._toggleOpen,
      listen: this._openChannel,
      stop: this._closeChannel,
      enable: this._enablePermanentListener,
      disable: this._disablePermanentListener,
      enabled: this.hasPermanentListener
    }
  }

  agentsNeeded = {}

  get channel() {
    return this._channel
  }

  set channel(channel) {
    if(channel !== this._channel) {
      this._channel = channel
      this.forceUpdate()
    }
    return this._channel
  }

  get hasPermanentListener() {
    try {
      return window.localStorage.getItem('keepChatOpen') === 'yes'
    } catch(err) {
      console.error(err)
      return false
    }
  }

  set hasPermanentListener(value) {
    try {
      window.localStorage.setItem('keepChatOpen', value ? 'yes' : 'no')
    } catch(err) {
      console.error(err)
    }

    this.setState({ enabled: this.hasPermanentListener })
    return this.hasPermanentListener
  }

  _closeChannel = () => {
    this.channel && ChatRoomsChannel.closeChannel(this._onMessageReceived)
    this.channel = null
  }

  _onMessageReceived = ({ eventType, data, ...opts}) => {
    switch (eventType) {
      case 'initial':
        if(data.status !== 'connected') break;
        // eslint-disable-next-line
      case 'connected':
        return this.channel.perform('joined')
      case 'received':
        try {
          const { action } = data
          switch (action) {
            case 'joined':
              this._setRooms(data)
              break;
            case 'new-message':
              this._newMessage(data)
              break;
            case 'agent-needed':
              this._setAgentStatus(data, true)
              break;
            case 'agent-found':
              this._setAgentStatus(data, false)
              break;
            case 'created':
            case 'updated':
            case 'presence':
              this._addRoom(data)
              break;
            case 'availability':
              this._setChatOpen(data)
              break;
            case 'closed':
              this._removeRoom(data)
              break;
            case 'error':
              return console.log("CHAT ERROR", eventType, data, opts)
            default:
              if(process.env.NODE_ENV === 'development') console.info(eventType, data, opts)
          }
        } catch(err) {
          console.error(err)
          this.setState({ error: err.message || err.toString() })
        }
        break;
      case 'disconnected':
        this.componentDidMount()
      //eslint-disable-next-line
      default:
        console.log(eventType, data)
    }
  }

  _indexCache = () =>
    this.setState(state => {
      const cache = {}
      for (let i = 0; i < this.state.rooms.length; i++) {
        cache[this.state.rooms[i].uuid] = i
      }
      return { cache }
    })

  _newMessage = (data) =>
    this.setState(state => {
      let found, latestMessage
      const rooms = [...state.rooms]
      for (let i = 0; i < rooms.length; i++) {
        const room = {...rooms[i]}
        if(room.uuid === data.uuid) {
          found = true
          room.lastMessage = new Date(data.lastMessage || data.last_message || room.lastMessage || 0)
          rooms[i] = room
          latestMessage = new Date(Math.max(state.latestMessage || 0, room.lastMessage))

          break;
        }
      }
      return found ? { rooms, latestMessage } : {}
    })

  _setChatOpen = ({ open = false, toggled_by = '' }) => this.setState({ open, toggled_by })

  _setRooms = ({ rooms = [], open, toggled_by }) => {
    let { latestMessage, rooms: oldRooms = [], open: wasOpen, toggled_by: wasToggledBy } = this.state
    oldRooms = [...(oldRooms || [])]

    if(typeof open === "undefined") open = !!wasOpen
    if(typeof toggled_by === "undefined") toggled_by = wasToggledBy || ''

    for (let i = 0; i < rooms.length; i++) {
      const room = rooms[i]
      room.lastViewed = new Date(+(window.localStorage.getItem(`chat-room-${room.uuid}`) || 0))
      room.lastMessage = new Date(room.lastMessage || room.last_message || 0)
      for (let oi = oldRooms.length - 1; oi > -1; oi--) {
        const old = oldRooms[oi]
        if(room.uuid === old.uuid) {
          room.lastViewed = new Date(Math.max(room.lastViewed, old.lastViewed || 0))
          window.localStorage.setItem(`chat-room-${room.uuid}`, +room.lastViewed)
          oldRooms.splice(oi, 1)
        }
      }
      latestMessage = new Date(Math.max(latestMessage || 0, room.lastMessage || 0))
    }
    this.setState({ rooms, latestMessage, open, toggled_by, loading: false })
  }

  _addRoom = ({ room, open, toggled_by }) =>
    this.setState(state => {
      let found
      if(typeof open === "undefined") open = !!state.open
      if(typeof toggled_by === "undefined") toggled_by = state.toggled_by || ''

      room.lastMessage = new Date(room.lastMessage || 0)
      room.lastViewed = new Date(+(window.localStorage.getItem(`chat-room-${room.uuid}`) || 0))
      const rooms = [...state.rooms]
      for (let i = 0; i < rooms.length; i++) {
        const old = rooms[i]
        if(old.uuid === room.uuid) {
          // if(new RegExp(room.uuid).test(window.location.pathname) && old.is_closed) window.location.reload()
          found = true
          room.lastMessage = new Date(Math.max(room.lastMessage || 0, old.lastMessage || 0))
          room.lastViewed = new Date(Math.max(room.lastViewed, old.lastViewed || 0))
          if(!room.is_closed) window.localStorage.setItem(`chat-room-${room.uuid}`, +room.lastViewed)
          rooms[i] = room
          break;
        }
      }
      if(!found) rooms.push(room)

      return { rooms, open, toggled_by }
    })

  _removeRoom = ({ uuid }) =>
    this.setState(state => {
      let found
      const rooms = [...state.rooms]
      for (let i = 0; i < rooms.length; i++) {
        const r = {...rooms[i]}
        if(r.uuid === uuid) {
          found = true
          r.is_closed = true
          window.localStorage.removeItem(`chat-room-${r.uuid}`)
          rooms[i] = r
          break;
        }
      }
      return found ? { rooms } : {}
    })

  _roomViewed = (uuid, timestamp) =>
    this.setState(state => {
      let found
      const rooms = [...state.rooms]
      for (let i = 0; i < rooms.length; i++) {
        const r = {...rooms[i]}
        if(r.uuid === uuid) {
          found = true
          r.lastViewed = timestamp
          rooms[i] = r
          window.localStorage.setItem(`chat-room-${r.uuid}`, +timestamp)
          break;
        }
      }
      if(found) {
        const latestView = new Date(Math.max(state.latestView || 0, timestamp || 0))
        window.localStorage.setItem("chat-room-latest-view", +latestView)
        return { rooms, latestView }
      } else {
        return {}
      }
    })

  _setAgentStatus = ({ uuid }, value) =>
    this.setState(state => {
      if(!value) clearTimeout(this.agentsNeeded[uuid])

      let found
      const rooms = [...state.rooms]
      for (let i = 0; i < rooms.length; i++) {
        const room = {...rooms[i]}
        if(room.uuid === uuid) {
          found = true
          room.staffNeeded = !!value
          rooms[i] = room
          break;
        }
      }
      if(value) {
        clearTimeout(this.agentsNeeded[uuid])
        this.agentsNeeded[uuid] = this._agentIsNeeded(uuid)
      }

      return found ? { rooms } : {}
    })

  _agentIsNeeded = (uuid) =>
    setTimeout(
      () =>
        new Notification(
          'Chat Agent Needed',
          {
            body: uuid,
            tag: "chat",
            requireInteraction: true,
            // actions: [
            //   { action: 'open', title: 'View' },
            //   { action: 'dismiss', title: 'Dismiss' }
            // ]
          }
        ),
      10000
    )

  _onError = (err) => {
    console.error(err)
    this.setState({ error: err.message || err.toString() })
  }

  _getChannel = async ({ token }) => {
    try {
      if(token) {
        if(!AuthStatus.authenticationProven) {
          ChatRoomsChannel.disconnect()
          return AuthStatus.reauthenticate()
        }
        this.channel = this.channel || ChatRoomsChannel.openChannel(this._onMessageReceived)
        this.setState({ available: true })
      } else {
        if(this.available) this.setState({ available: false })
      }
    } catch(err) {
      console.error(err)
      if(this.available) this.setState({ available: false })
    }
  }

  _checkForUpdates = () => {
    this.channel && this.channel.perform('check', { updated: this.state.latestView || new Date() })
  }

  _toggleOpen = () => {
    this.channel && this.channel.perform('availability', { open: !this.state.open })
  }

  _openChannel = () => AuthStatus.subscribeAndCall(this._getChannel)

  _disablePermanentListener = () =>
    this.hasPermanentListener = false

  _enablePermanentListener = () =>
    this.hasPermanentListener = true

  componentDidMount() {
    if(this.hasPermanentListener) this._openChannel()
  }

  componentWillUnmount() {
    AuthStatus.unsubscribe(this._getChannel)
    this._closeChannel()
  }

  componentDidUpdate(props, state) {
    if(state.rooms !== this.state.rooms) this._indexCache()
  }

  render() {
    return (
      <ChatRooms.Context.Provider
        value={this.state}
      >
        {this.props.children}
      </ChatRooms.Context.Provider>
    )
  }
}
