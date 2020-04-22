import React from 'react';
import { ChatRooms } from 'contexts/chat-rooms';
import Component from 'common/js/components/component'
import { Link } from 'react-component-templates/components';
import './index.css'
import Chat from 'components/chat'
import Atom from 'load-awesome-react-components/dist/ball/atom'
import 'load-awesome-react-components/dist/ball/atom.css'

const chatRoomUrl = '/admin/chat/:uuid'

export default class ChatPage extends Component {
  static contextType = ChatRooms.Context

  state = { uuid: false }

  get rooms() {
    return (this.context && this.context.rooms) || []
  }

  get currentRoom() {
    const index = (this.context || {}).cache[this.state.uuid]
    return index === undefined ? {} : this.rooms[index]
  }

  get uuid(){
    try {
      const { match: { params: { uuid } } } = this.props
      return uuid
    } catch(_) {
      return this.state.uuid
    }
  }

  updateLoop = () => {
    clearTimeout(this._updateLoop)
    if(this.context.ping) this.context.ping()
    this._updateLoop = setTimeout(this.updateLoop, (60 * 1000))
  }

  componentDidMount() {
    this.context.listen()
    if(this.uuid !== this.state.uuid) this.setState({ uuid: this.uuid })
    this.updateLoop()
  }

  componentDidUpdate() {
    if(this.uuid !== this.state.uuid) this.setState({ uuid: this.uuid })
  }

  componentWillUnmount() {
    clearTimeout(this._updateLoop)
    setTimeout(() => {
      clearTimeout(this._updateLoop)
    })
  }

  _getRoom = (uuid) => {
    for (let i = 0; i < this.rooms.length; i++) {
      const room = this.rooms[i]
      if(room.uuid === uuid) return { room }
    }
    return { room: {} }
  }

  showChat = (ev) => {
    // ev.preventDefault()
    // ev.stopPropagation()
    this.setState({ uuid: ev.currentTarget.dataset.uuid || false })
  }

  roomListClass(room) {
    const lastViewed = new Date(room.lastViewed || 0),
          lastMessage = new Date(room.lastMessage || 0)
    return lastMessage > lastViewed ? 'notify' : ''
  }

  render() {
    const { uuid: current = false } = this.state
    return (
      <section className="Chat row">
        <header className="col-12 text-center">
          <button className="btn btn-warning float-left" type="button" onClick={this.context.enabled ? this.context.disable : this.context.enable}>
            { this.context.enabled ? 'Disable' : 'Enable' } Permanent Listener
          </button>
          <button className={`btn btn-${this.context.open ? 'danger' : 'success'} float-right`} type="button" onClick={this.context.toggleAvailability}>
            Toggle Chat Availability
          </button>
          <h3 className={this.context.open ? "text-default" : "text-danger"}>
            Chat Rooms ({this.context.open ? 'Open' : 'Closed'}{this.context.toggled_by && ` - Toggled By: ${this.context.toggled_by}`})
          </h3>
          <hr/>
        </header>
        <div className="col-12">
          <div className="clearfix"></div>
          {
            !!this.context.loading && (
              <div className="d-flex justify-content-center align-items-center text-dark vh-50">
                <Atom className="la-vh-sm text-primary" />
              </div>
            )
          }
        </div>
        <div className="col-md-4 chat-links">
          {
            this.rooms.map(({uuid, name, phone, email, connected_staff, is_closed, ...room}) => (
              !is_closed && (
                <Link
                  data-uuid={uuid}
                  onClick={this.showChat}
                  key={uuid}
                  to={chatRoomUrl.replace(":uuid", uuid)}
                  className={current === uuid ? 'active' : this.roomListClass(room)}
                >
                  { `${name}: ${phone}; Staff Connected: ${connected_staff}` }
                </Link>
              )
            ))
          }
        </div>
        <div className="col-md-8">
          {
            !!current && <Chat key={current} {...this.currentRoom} uuid={current} onView={this.context.onView} latestView={this.context.latestView} latestMessage={this.context.latestMessage} />
          }
        </div>
      </section>
    );
  }
}
