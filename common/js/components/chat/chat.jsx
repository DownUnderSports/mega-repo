import React, { Component } from 'react'
import ChatDisplay from 'common/js/components/chat/components/display'

const Chat = {}

const inDevelopment = process.env.NODE_ENV === 'development'
let channelLoaded
let ChatMessagesChannel = {
  closeChannel: async (...args) => (await Chat.loadChannel()).closeChannel(...args),
  openChannel: async (...args) => (await Chat.loadChannel()).openChannel(...args)
}

Chat.loadChannel = async () => {
  if(channelLoaded) return await channelLoaded
  channelLoaded = new Promise(async r => {
    const result = await import(/* webpackChunkName: "chat-messages-channel" */ 'common/js/channels/chat-messages')

    ChatMessagesChannel = result.default
    r(ChatMessagesChannel)
  })
  return await channelLoaded
}

export default class ReduxChatProvider extends Component {
  constructor(props) {
    super(props)
    this.state = {
      error: false,
      staffIsConnected: false,
      messages: [],
      chatIsOpen: false,
      // chatIsOpen: !!window.localStorage.getItem('DownUnderSportsChatID'),
      uuid: window.localStorage.getItem('DownUnderSportsChatID'),
      hideChat: this.hideChat,
      showChat: this.showChat,
      toggleChat: this.toggleChat,
      renderForm: this._renderForm,
      typing: false,
      admin: false,
      userDisconnected: false,
      inactive: false,
    }
  }

  async componentDidMount() {
    this._mounted = true
    await this._getChannelAndScroll()
  }

  componentWillUnmount() {
    this._mounted = false
    this._unsubscribe()
  }

  setStateIfMounted = (...args) => this._mounted && this.setState(...args)

  _active = () => {
    this.channel && this.channel.perform("available")
  }

  _addMessage = message =>
    this.setStateIfMounted({ messages: [...(this.state.messages || []), message] }, this._scrollToBottom)

  _channelRetrieved = async () => {
    if(this.channel || !this.state.uuid) return this.channel
    return new Promise(r => setTimeout(async () => r(await this._channelRetrieved()), 100))
  }

  _closeChannel = async (uuid) => {
    try {
      if(!uuid || (window.localStorage.getItem('DownUnderSportsChatID') === uuid)) {
        window.localStorage.removeItem('DownUnderSportsChatID')
      }
    } catch (e) {
      console.error(e)
    }


    if(uuid || this.channel) ChatMessagesChannel.closeChannel(uuid || this.state.uuid)
    if(!this.state.uuid || (this.state.uuid === uuid) || !uuid) this.channel = null
  }

  _getChannel = async () => {
    if(!this.state.uuid || !this._mounted) return false
    if(this._isRetreiving) return await this._channelRetrieved()

    this._isRetreiving = true
    await Chat.loadChannel()
    this.channel = this.channel || ChatMessagesChannel.openChannel(this.state.uuid, this._onMessageReceived)
    this._isRetreiving = false
    return this.channel
  }

  _getChannelAndScroll = async () => {
    if(this.state.chatIsOpen) {
      await this._getChannel()
      this._scrollToBottom()
    }
  }

  _getStaff = (tries) => {
    if(this.state.admin) return this._staffConnected()
    if(!this.channel || !this.state.uuid) {
      if((tries || 0) > 5) return false
      return setTimeout(() => this._getStaff((tries || 0) + 1), 100)
    }
    this.channel && this.channel.perform('agent', { uuid: this.state.uuid })
  }

  _isTyping = ({ staff, id, active: typing }) => (!!staff !== this.state.admin) && this.setStateIfMounted({ typing })

  _markedInactive = ({data, uuid}) => {
    this._unsubscribe()
    this.setStateIfMounted({ staffIsConnected: false, inactive: true })
  }

  _onConnected = () => {
    this.channel.perform('joined')
  }

  _onDisconnected = () => {
    clearTimeout(this._pingTimeout)
    this._pingTimeout = null
    clearTimeout(this.respondingTimeout)
    this.respondingTimeout = null
    clearTimeout(this._staffCheck)
    this._staffCheck = null
  }

  _onError = (err) => {
    console.error(err)
    this.setStateIfMounted({ error: err.message || err.toString() })
  }

  _onMessageReceived = ({ eventType, data, uuid, ...opts}) => {
    if(inDevelopment) console.info(eventType, data, uuid, opts)
    if(data && data.statusChange) this.forceUpdate()

    switch (eventType) {
      case 'connected':
        return this._onConnected()
      case 'received':
        return this._onNewMessage({data, uuid, opts})
      default:
        if(data && data.statusChange) this.forceUpdate()
    }
  }

  _onNewMessage = ({data, uuid, opts}) => {
    try {
      const { action } = data

      switch (uuid && action) {
        case 'joined':
          return (
            data.closed
              ? this._markedInactive({data, uuid})
              : this._setMessages(data.messages || [])
            )
        case 'verify':
          return this._verifyConnected(data)
        case 'ping':
          return this._active()
        case 'active':
          return this._pingFound(true)
        case 'chat':
          return this._addMessage(data.message)
        case 'agent-check':
          return this._staffConnected()
        case 'agent-found':
          return this._staffFound()
        case 'typing':
          return this._isTyping(data)
        case 'user-disconnected':
          return this._userDisconnected(data)
        case 'marked-inactive':
          return this._markedInactive({data, uuid})
        case 'closed':
          return this.closeChat()
        default:
          if(inDevelopment) console.info(opts, data)
      }
    } catch(err) {
      console.error(err)
      this.setStateIfMounted({ error: err.message || err.toString() })
    }
  }

  _pingFound = (active) => {
    clearTimeout(this._pingTimeout)
    this._pingTimeout = null
    if(active === true) this.setStateIfMounted({ userDisconnected: false })
  }

  _scrollToBottom = (tries) => {
    try {
      if(!this.chatMessageEl) {
        if((tries || 0) > 3) return false
        return setTimeout(() => this._scrollToBottom((tries || 0) + 1), 100)
      }
      this.chatMessageEl.scrollTop = this.chatMessageEl.scrollHeight
    } catch (e) {
     console.error(e)
    }
  }

  _setMessages = messages => this.setStateIfMounted({ messages, staffIsConnected: false, joinedAt: new Date(), inactive: false }, this._getStaff)

  _staffConnected = async (tries) => {
    if(!this.state.admin) {
      clearTimeout(this._staffCheck)
      this._staffCheck = setTimeout(() => this.setStateIfMounted({ staffIsConnected: false }, this._getStaff), 10000)
    } else {
      await this._getChannel()

      if(!this.channel || !this.state.uuid) {
        if(!this._mounted || ((tries || 0) > 5)) return false
        return setTimeout(() => this._staffConnected((tries || 0) + 1), 100)
      }

      this.channel && this.channel.perform("available")
    }
  }

  _staffFound = () => {
    clearTimeout(this._staffCheck)
    this.setStateIfMounted({ staffIsConnected: true })
  }

  _unsubscribe = () => {
    if(this.channel && this.state.uuid) {
      ChatMessagesChannel.closeChannel(this.state.uuid, this._onMessageReceived)
      this.channel = null
    }
  }

  _userDisconnected = (data) => {
    this._pingFound()
    this.setStateIfMounted({ userDisconnected: true })
  }

  _verifyConnected = ({ timestamp }) => {
    if(this.channel && (!this.state.joinedAt || (new Date(timestamp) > this.state.joinedAt))) {
      this.channel.perform('verify')
      setTimeout(this._staffConnected, 1000)
    }
  }

  chatMessageRef = (chatMessageEl) => {
    this.chatMessageEl = chatMessageEl
  }

  closeChat = (restart = false) => {
    this.channel = null
    const { uuid } = this.state
    this.setStateIfMounted({ uuid: null, chatIsOpen: restart === "NEW CHAT" }, () => this._closeChannel(uuid))
  }

  hideChat = () => this.setStateIfMounted({ chatIsOpen: false })

  newChat = () => this.closeChat("NEW CHAT")

  onChatSessionCreated = ({ uuid, ...props}) => {
    console.log(uuid, props)
    window.localStorage.setItem('DownUnderSportsChatID', uuid)
    this.setStateIfMounted({ uuid, inactive: false, chatIsOpen: true }, this._getChannelAndScroll)
  }

  ping = () => {
    if(this.channel && !this._pingTimeout) {
      this._pingTimeout = setTimeout(this._userDisconnected, 5000)
      this.channel.perform("ping")
    }
  }

  showChat = () => this.setStateIfMounted({ chatIsOpen: true }, this._getChannelAndScroll)

  submitMessage = (ev) => {
    ev && ev.preventDefault()
    const el = document.getElementById('chat-input'),
          message = el.value
    console.log(el, message)
    if(this.channel && message) {
      this.doneResponding()
      this.channel.perform('chat', { message })
    }

    el.value = ''
  }

  toggleChat = () => this.setStateIfMounted({ chatIsOpen: !this.state.chatIsOpen }, this._getChannelAndScroll)

  isResponding = async () => {
    console.log('TYPING');
    clearTimeout(this.respondingTimeout)
    if(this.channel) {
      this.channel.perform('typing', { active: true })
      this.respondingTimeout = setTimeout(this.doneResponding, 2000)
    } else {
      await this._getChannel()
    }
  }

  doneResponding = async () => {
    clearTimeout(this.respondingTimeout)
    await this._getChannel()
    if(this.channel) this.channel.perform('typing', { active: false })
  }

  render() {
    return (
      <ChatDisplay
        wrapperId={this.props.id}
        chatMessageRef={this.chatMessageRef}
        closeChat={this.closeChat}
        hideChat={this.hideChat}
        newChat={this.newChat}
        onChatSessionCreated={this.onChatSessionCreated}
        submitMessage={this.submitMessage}
        toggleChat={this.toggleChat}
        chatIsOpen={!!this.state.chatIsOpen}
        messages={this.state.messages || []}
        staffIsConnected={!!this.state.staffIsConnected}
        status={this.channel && this.channel.status}
        uuid={this.state.uuid}
        onKeyDown={this.isResponding}
        typing={this.state.typing}
        key={this.state.uuid || 'display'}
        inactive={this.state.inactive}
      />
    )
  }
}
