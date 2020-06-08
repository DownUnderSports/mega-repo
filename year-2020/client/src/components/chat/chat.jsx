import React from 'react'
import ClientChat from 'common/js/components/chat'
import ChatDisplay from 'components/chat/components/admin-display'
import { CurrentUser } from 'common/js/contexts/current-user'
import throttle from 'common/js/helpers/throttle'

export default class Chat extends ClientChat {
  static contextType = CurrentUser.Context

  constructor(props) {
    super(props)
    this.state.admin = true
    this.state.uuid = this.props.uuid
    this._latestView = throttle(this._unthrottledLatestView, (3 * 1000), true)
  }

  async componentDidMount() {
    await ClientChat.prototype.componentDidMount.call(this)
    await this._getChannel()
    if(!this.context.currentUserState.loaded) await this.context.currentUserActions.getCurrentUser()
    this._latestView()
  }

  async componentDidUpdate(props, state) {
    let closeChanged
    if(this.state.uuid !== state.uuid) {
      closeChanged = !this.props.is_closed
      this._closeChannel(state.uuid)
      this.channel = null
    } else if(props.is_closed !== this.props.is_closed) {
      closeChanged = !this.props.is_closed
      this._closeChannel()
      this.channel = null
    }
    if(closeChanged){
      await this._getChannel()
      this._pingFound()
    }
    this._latestView()
  }

  static getDerivedStateFromProps(nextProps, state) {
    if(nextProps.uuid !== state.uuid) {
      return {
        uuid: nextProps.uuid
      }
    }
    return null
  }

  get userId() {
    try {
      return this.context.currentUserState.id
    } catch(_) {
      return void(0)
    }
  }

  _unthrottledLatestView = () => {
    if(this.props.onView && (new Date(Math.max(this.props.latestMessage || 0, this.props.lastMessage || 0)) > new Date(Math.min(this.props.latestView || this.props.lastViewed || 0, this.props.lastViewed || 0)))) {
      this._lastMessageRespondedTo = this.props.latestMessage
      const timestamp = new Date(), { uuid } = this.state
      this.props.onView(uuid, timestamp)
    }
  }

  _isTyping = ({ staff, id, active }) => {
    console.log({
      typing: !!active ? (staff ? 'Staff' : 'Client') : 'no',
      userDisconnected: this.state.userDisconnected,
      staff,
      id,
      myId: this.userId,
      admin: this.state.admin
    });

    if((!!staff !== this.state.admin) || (id !== this.userId)) this.setStateIfMounted({ typing: !!active && (staff ? 'Staff' : 'Client'), userDisconnected: this.state.userDisconnected && !!staff  })
  }

  _markedInactive = ({data, uuid}) => {
    this.setStateIfMounted({ messages: ((data || {}).messages || this.state.messages) }, this._scrollToBottom)
  }

  saveMeta = (ev) => {
    ev && ev.preventDefault()
    const emailEl = document.getElementById('chat-email'),
          phoneEl = document.getElementById('chat-phone'),
          email = emailEl.value,
          phone = phoneEl.value

    if(this.channel && (email || phone)) this.channel.perform('meta', { email, phone })
  }

  markInactive = (ev) => {
    ev && ev.preventDefault()
    console.log(this.channel)

    if(this.channel) this.channel.perform('inactive')
  }

  render() {
    return (
      <ChatDisplay
        chatMessageRef={this.chatMessageRef}
        submitMessage={this.submitMessage}
        saveMeta={this.saveMeta}
        markInactive={this.markInactive}
        messages={this.state.messages || []}
        status={this.channel && this.channel.status}
        uuid={this.state.uuid}
        onKeyDown={this.isResponding}
        typing={this.state.typing}
        key={this.props.uuid || "display"}
        name={this.props.name}
        email={this.props.email}
        phone={this.props.phone}
        closed={this.props.is_closed}
        userId={this.userId}
        ping={this.ping}
        disconnected={this.state.userDisconnected}
        inactive={this.state.inactive}
      />
    )
  }
}
