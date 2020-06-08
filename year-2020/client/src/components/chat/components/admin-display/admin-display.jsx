import React, { Component } from 'react'
import Pulse from 'load-awesome-react-components/dist/ball/pulse'
import 'load-awesome-react-components/dist/ball/pulse.css'
import './admin-display.css'
import QuickReplies from 'components/chat/components/quick-replies'
import FaqReplies from 'components/faq-replies'
import CopyClip from 'common/js/helpers/copy-clip'
import { format as dateFormat } from 'date-fns'

export default class AdminChatDisplay extends Component {
  chatMessageRef = (...args) => this.props.chatMessageRef && this.props.chatMessageRef(...args)
  submitMessage = (...args) => this.props.submitMessage && this.props.submitMessage(...args)
  saveMeta = (...args) => this.props.saveMeta && this.props.saveMeta(...args)
  markInactive = (...args) => this.props.markInactive && this.props.markInactive(...args)
  isMine = (message) =>
    this.props.userId === message.user_id

  _staffMessage = (m) => {
    if(!m.user_id) return false
    return (
      <>
        <div key="label" className="chat-label right">{ m.user_name }: {this._timestamp(m.created_at)}</div>
        <div
          key="message"
          className="chat-bubble right"
          dangerouslySetInnerHTML={this._createMarkup(m.message)}
        />
      </>
    )
  }

  _submitOnCtrlEnter = (ev) => {
    if(!ev) return false
    else if(ev.ctrlKey && ((ev.key === "Enter") || (ev.which === 13))) {
      this.submitMessage(ev)
      return true
    }
  }

  _userMessage = (m) => {
    if(!!m.user_id) return false
    return (
      <>
        <div key="label" className="chat-label left">{ this.props.name }: {this._timestamp(m.created_at)}</div>
        <div
          key="message"
          className="chat-bubble left"
          dangerouslySetInnerHTML={this._createMarkup(m.message)}
        />
      </>
    )
  }

  _timestamp(time) {
    if(!time) return false
    const d = new Date(time)
    return <span className="text-muted timestamp">{ dateFormat(d, 'MMM Do @ HH:mm:ss') }</span>
  }

  _createMarkup(msg) {
    return {__html: msg.replace(/(https?:\/\/[^\s]+)/g, "<a href=\"$1\" target=\"_chatLink\" rel=\"noopener noreferrer\">$1</a>") }
  }

  _onKeyDown = (ev) => {
    if(!this._submitOnCtrlEnter(ev)) this.props.onKeyDown && this.props.onKeyDown(ev)
  }

  _chatLink = () => {
    CopyClip.prompted(`https://admin.downundersports.com/admin/chat/${this.props.uuid}`)
  }

  _messageRef = el => this.messageEl = el

  faqReplyClick = ({ text }) => this.setMessage(text || '')

  pingLoop = () => {
    clearTimeout(this._pingLoop)
    if(this.props.ping && !this.connectionLost) this.props.ping()
    this._pingLoop = setTimeout(this.pingLoop, (15 * 1000))
  }

  // async componentDidMount() {
  //   if(!this.context.currentUserState.loaded) await this.context.currentUserActions.getCurrentUser()
  // }

  setMessage = (msg) => {
    try {
      const el = this.messageEl
      console.log(el)
      el.value = msg
      el.focus()
      this._onKeyDown()
    } catch(_) {}
  }


  componentDidMount() {
    this.pingLoop()
  }

  componentWillUnmount() {
    this.ac = null
    clearTimeout(this._pingLoop)
    setTimeout(() => {
      clearTimeout(this._pingLoop)
    })
  }

  get connectionLost() {
    return this.props.status === 'disconnected'
  }

  get disconnected() {
    return this.connectionLost || !!this.props.disconnected
  }

  get ac() {
    return this._ac = this._ac || `false ${+(new Date())}`
  }

  set ac(val) {
    this._ac = val
  }

  get messageEl() {
    return this._messageEl || document.getElementById('chat-input')
  }

  set messageEl(el) {
    return this._messageEl = el
  }

  render() {
    const ac = this.ac
    return (
      <div className={`d-print-none chat-wrapper ${this.props.closed || !this.props.uuid || this.disconnected}`}>
        {
          (this.props.closed || !this.props.uuid)
            ? (
                <div className="row mb-3 chat-header">
                  <div className="col text-center">
                    <h3>
                      Chat Closed by Staff or User
                    </h3>
                  </div>
                </div>
              )
            : (
                this.disconnected && (
                  <div className="row mb-3 chat-header">
                    {
                      this.connectionLost
                        ? (
                            <div className="col text-center">
                              <h3>
                                Lost Connection <span className="d-inline-block"><Pulse className="text-white" /></span>
                              </h3>
                              <h4>
                                Please wait while we reconnect.
                              </h4>
                            </div>
                          )
                        : (
                            <div className="col text-center">
                              <h3>
                                User Disconnected
                              </h3>
                            </div>
                          )
                    }
                  </div>
                )
              )
        }
        <div className="row mb-3 chat-header">
          <div className="col-auto">Chatting With:</div>
          <div className="col">
            <div className="d-flex justify-content-between">
              { this.props.name }
              <a href={`mailto:${this.props.email}`}>
                {this.props.email}
              </a>
              <a href={`tel:${this.props.phone}`}>
                {this.props.phone}
              </a>
            </div>
          </div>
          <div className="col-auto">
            <button className="btn btn-info" onClick={this._chatLink}>Copy Link</button>
          </div>
          {
            !this.props.inactive && (
              <div className="col-auto">
                <button className="btn btn-danger" onClick={this.markInactive}>Mark Inactive!</button>
              </div>
            )
          }
        </div>
        <div className="row mb-3">
          <div className="col" key={this.props.email || 'email-wrapper'}>
            <label htmlFor="chat-email">Email</label>
            <input className="form-control" type="email" id="chat-email" defaultValue={this.props.email || ''} name={ac} autoComplete={ac}/>
          </div>
          <div className="col" key={this.props.phone || 'phone-wrapper'}>
            <label htmlFor="chat-phone">Phone</label>
            <input className="form-control" type="text" id="chat-phone" defaultValue={this.props.phone || ''} name={ac} autoComplete={ac} />
          </div>
          <div className="col-auto">
            <label>&nbsp;</label>
            <button className="btn btn-info d-block" onClick={this.saveMeta}>
              Save
            </button>
          </div>
        </div>


        <div className="chat-messages" ref={this.chatMessageRef}>
          {
            this.props.messages.map(
              m => (
                <div className="row" key={m.id}>
                  <div className="col">
                    { this._userMessage(m) }
                  </div>
                  <div className="col">
                    { this._staffMessage(m) }
                  </div>
                </div>
              )
            )
          }
          <div className="clearfix"></div>
          {
            !!this.props.typing && (
              <div className="row">
                <div className="col-12">
                  <h4 className="text-center">
                    { this.props.typing } is Typing
                  </h4>
                </div>
                <div className="col-12">
                  <div className="d-flex justify-content-center text-dark">
                    <Pulse className="la-2x text-dark" />
                  </div>
                </div>
              </div>
            )
          }
        </div>
        <div className="row mt-3">
          <div className="col">
            <label htmlFor="chat-input">Enter Message</label>
            <textarea ref={this._messageRef} className="form-control" type="text" id="chat-input" onKeyDown={this._onKeyDown} rows="5"/>
          </div>
        </div>
        <div className="row mt-3">
          <div className="col">
            <button className="btn btn-block btn-success" onClick={this.submitMessage}>
              <span className="spread-items">
                <i className="material-icons">add_comment</i> <strong>Send</strong>
              </span>
            </button>
          </div>
        </div>
        <hr/>
        <QuickReplies setMessage={this.setMessage} {...this.props}/>
        <hr/>
        <h3>
          F.A.Q. Replies
        </h3>
        <FaqReplies className="quick-replies" onClick={this.faqReplyClick} />
      </div>
    )
  }
}
