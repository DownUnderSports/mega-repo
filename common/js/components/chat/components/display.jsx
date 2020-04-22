import React, { Component } from 'react'
import NewChatForm from 'common/js/forms/new-chat-form'

let PulseComponent = () => <div></div>

let pulseLoaded

const loadPulse = async (cb) => {
  if(pulseLoaded) return await pulseLoaded
  pulseLoaded = new Promise(async r => {
    await import(/* webpackChunkName: "pulse-ball-loader" */ 'load-awesome-react-components/dist/ball/pulse.css')
    const result = await import(/* webpackChunkName: "pulse-ball-loader-component" */ 'load-awesome-react-components/dist/ball/pulse')

    PulseComponent = result.default
    r(PulseComponent)
  })
  await pulseLoaded
  cb && cb()
  return PulseComponent
}

let Pulse = ({afterLoad: _, ...props}) => {
  loadPulse(props.afterLoad)
  return <PulseComponent {...props} />
}

export default class ChatDisplay extends Component {
  chatMessageRef = (...args) => this.props.chatMessageRef && this.props.chatMessageRef(...args)
  closeChat = (...args) => this.props.closeChat && this.props.closeChat(...args)
  hideChat = (...args) => this.props.hideChat && this.props.hideChat(...args)
  onChatSessionCreated = (...args) => this.props.onChatSessionCreated && this.props.onChatSessionCreated(...args)
  submitMessage = (...args) => this.props.submitMessage && this.props.submitMessage(...args)
  toggleChat = (...args) => this.props.toggleChat && this.props.toggleChat(...args)
  newChat = (...args) => this.props.newChat && this.props.newChat(...args)
  isMine = (message) =>
    this.props.userId === message.user_id

  afterPulseLoaded = () => this.forceUpdate()

  _staffMessage = (m) => {
    if(!m.staff) return false
    return (
      <div
        className="chat-bubble left"
        dangerouslySetInnerHTML={this._createMarkup(m.message)}
      />
    )
  }

  _submitOnCtrlEnter = (ev) =>
    (ev.ctrlKey && ((ev.key === "Enter") || (ev.which === 13)))
    && (
      !!this.submitMessage(ev)
      || true
    )

  _userMessage = (m) => {
    if(m.staff) return false
    return (
      <>
        <div key="label" className="text-right"><strong>You:</strong></div>
        <div
          key="bubble"
          className="chat-bubble right"
          dangerouslySetInnerHTML={this._createMarkup(m.message)}
        />
      </>
    )
  }

  _onKeyDown = (ev) => {
    if(!this._submitOnCtrlEnter(ev)) this.props.onKeyDown && this.props.onKeyDown(ev)
  }

  _verifyStructure = () => {
    if(!document.getElementsByClassName('chat-wrapper').length) {
      this.ct = (this.ct || 0) + 1
      if(this.ct < 10) this.forceUpdate()
    } else {
      this.ct = 0
    }
  }

  _createMarkup(msg) {
    return {__html: msg.replace(/(https?:\/\/[^\s]+)/g, "<a href=\"$1\" target=\"_chatLink\" rel=\"noopener noreferrer\">$1</a>") }
  }

  componentDidMount() {
    this._verifyStructure()
  }

  componentDidUpdate() {
    this._verifyStructure()
  }

  get id() {
    return this.props.wrapperId || `chat-wrapper-${this.props.uuid || 'chat'}`
  }

  get disconnected() {
    return (this.props.status === 'disconnected') ? 'disconnected' : ''
  }

  render() {
    const disconnected = this.disconnected
    return (
      <div key="wrapper" id={this.id} ref="wrapper" className={`d-print-none chat-wrapper ${disconnected} ${!!this.props.chatIsOpen}`}>
        {
          this.props.chatIsOpen
            ? (
                !this.props.uuid
                  ? <NewChatForm key="form" onSuccess={this.onChatSessionCreated} onCancel={this.hideChat} />
                  : (
                    this.props.inactive
                      ? <NewChatForm key={this.props.uuid} onSuccess={this.onChatSessionCreated} onCancel={this.newChat} uuid={this.props.uuid} />
                      : (
                          <>
                            <div key="top-row" className="row mb-3">
                              <div className="col-auto">
                                <button className="btn with-icon btn-primary" onClick={this.toggleChat}>
                                  <i className="material-icons large">arrow_drop_down</i>
                                </button>
                              </div>
                              <div className="col text-center">
                                {
                                  /ing$/.test(this.props.status)
                                    ? `${this.props.status.titleize()} ${/^dis/.test(this.props.status) ? 'from' : 'to'} Server...`
                                    : (
                                        disconnected && (
                                          <h4>
                                            Lost Connection <span className="d-inline-block"><Pulse afterLoad={this.afterPulseLoaded} className="text-white" /></span>
                                          </h4>
                                        )
                                      )
                                }
                              </div>
                              <div className="col-auto">
                                <button className="btn btn-icon btn-danger" onClick={this.closeChat}>
                                  <i className="material-icons large">cancel</i>
                                </button>
                              </div>
                            </div>
                            <div key="warning-row" className="row">
                              {
                                disconnected && (
                                  <div key="warning-header" className="col mb-3 text-center">
                                    <h5>
                                      Please wait while we reconnect.
                                    </h5>
                                  </div>
                                )
                              }
                            </div>
                            <div key="messages-row" className="chat-messages" ref={this.chatMessageRef}>
                              {
                                this.props.messages.map(
                                  m => (
                                    <div className="row" key={m.id}>
                                      <div className="col">
                                        { this._staffMessage(m) }
                                      </div>
                                      <div className="col">
                                        { this._userMessage(m) }
                                      </div>
                                    </div>
                                  )
                                )
                              }
                              <div key="message-clearfix" className="clearfix"></div>
                              {
                                !!this.props.typing ? (
                                  <div key="is-typing" className="d-flex justify-content-center text-dark">
                                    <Pulse
                                      afterLoad={this.afterPulseLoaded}
                                      className="la-2x text-dark"
                                    />
                                  </div>
                                ) : (
                                  !this.props.staffIsConnected && (
                                    <div key="not-connected" className="row">
                                      <div className="col text-center">
                                        <h4>Searching for Available Staff</h4>
                                        <div className="d-flex justify-content-center text-dark">
                                          <Pulse
                                            afterLoad={this.afterPulseLoaded}
                                            className="la-2x text-dark"
                                          />
                                        </div>
                                      </div>
                                    </div>
                                  )
                                )
                              }
                            </div>
                            <div key="message-input" className="row mt-3">
                              <div className="col">
                                <label htmlFor="chat-input">Enter Message</label>
                                <textarea className="form-control" type="text" id="chat-input" onKeyDown={this._onKeyDown} rows="3"/>
                              </div>
                            </div>
                            <div key="add-button" className="row mt-3">
                              <div className="col">
                                <button className="btn btn-block btn-success" onClick={this.submitMessage}>
                                  <span className="spread-items">
                                    <i className="material-icons">add_comment</i> <strong>Send</strong>
                                  </span>
                                </button>
                              </div>
                            </div>
                          </>
                        )
                  )
              )
            : (
                <button
                  key="toggle-button"
                  className="chat-btn btn btn-info"
                  onClick={this.toggleChat}
                >
                  <i className="material-icons">chat</i> Chat With Us
                </button>
              )
        }
      </div>
    )
  }
}
