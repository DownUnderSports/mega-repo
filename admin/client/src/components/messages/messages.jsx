import React, { Component } from 'react'
import { DisplayOrLoading, CardSection } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import { Objected } from 'react-component-templates/helpers';
import MessageInfo from './message-info'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import RunningDots from 'load-awesome-react-components/dist/ball/running-dots'

import './messages.css'

const baseUrl = '/admin/users'

export default class Messages extends Component {
  get lastMessage() {
    if(this._lastMessage !== undefined) return this._lastMessage
    try {
      return this._lastMessage = (this.state.messages && this.state.messages[this.state.messages.length - 1])
    } catch(e) {
      return this._lastMessage = null
    }
  }

  get lastMessageIsNew() {
    if(this._lastMessageIsNew !== undefined) return this._lastMessageIsNew
    return this._lastMessageIsNew = !!this.lastMessage && !this.lastMessage.id
  }

  constructor(props) {
    super(props)
    this.state = { messages: [], allMessages: [], reloading: true }
  }

  async componentDidMount(){
    this._isMounted = true
    await this.getMessages()
  }

  componentWillUnmount(){
    this.abortFetch()
    this._isMounted = false
  }

  shouldComponentUpdate(_, nextState) {
    if(this.state.messages !== nextState.messages) {
      this._lastMessage = undefined
      this._lastMessageIsNew = undefined
    }
    return true
  }

  async componentDidUpdate(prevProps, prevState) {
    if(
      (prevProps.id !== this.props.id)
      || (prevProps.lastFetch !== this.props.lastFetch)
    ) await this.getMessages()
  }

  category() {
    return 'Messages';
  }

  type() {
    return false
  }

  abortFetch = () => {
    if(this._fetchable) {
      if(!this._fetchable.abort) console.log(this._fetchable, fetch)
      this._fetchable.abort()
    }
  }

  forceGetMessages = () => this.getMessages(true)

  getMessages = async (force = false) => {
    if(this._isMounted){
      this.setState({ reloading: true })
      try {
        this.abortFetch()
        if(!this.props.id) throw new Error(`Messages (${this.type()}): No User ID`)
        this._fetchable = fetch(`${baseUrl}/${this.props.id}/messages.json?type=${this.type()}&force=${force ? 1 : 0}`, {timeout: 5000})
        const result = await this._fetchable,
              retrieved = await result.json()

        if(this._isMounted) {
          this.setState({
            reloading: false,
            allMessages: [...retrieved.messages],
            ...retrieved,
          })
        }

      } catch(e) {
        if(this._isMounted) {
          console.error(e)
          this.setState({
            reloading: false,
            allMessages: [],
            messages: [],
          })
        }
        return false
      }
    }
    return true
  }

  filter = (val) => {
    const reg = val && new RegExp(val, 'i')
    this.setState({
      messages: val ? this.state.allMessages.filter((m) => {
        for(let k in Objected.filterKeys(m, ['id', 'user_id', 'staff_id', 'type', 'categories'])) {
          if(m.hasOwnProperty(k) && reg.test(`${m[k] || ''}`)) return true
        }
        return false
      }) : [...this.state.allMessages]
    })
  }

  newMessage = async () => {
    if(this.state.fetchingNewMessage || this.lastMessageIsNew) return false
    this.setState({ reloading: true, fetchingNewMessage: true })
    try {
      const result = await fetch(`${baseUrl}/${this.props.id || 0}/messages/new.json?type=${this.type()}`),
            retrieved = await result.json()

      this.setState({
        reloading: false,
        fetchingNewMessage: false,
        messages: [...this.state.messages, retrieved],
      })

    } catch(e) {
      this.setState({
        reloading: false,
        fetchingNewMessage: false,
        messages: [],
      })
    }
  }

  removeMessage = (i) => {
    const {messages = []} = this.state
    this.setState({messages: [...messages.slice(0, i), ...messages.slice(i + 1)]})
  }

  onSuccess = () => this.getMessages()

  render() {
    const { reloading = false, fetchingNewMessage = false } = this.state || {},
          disableNewMessageButton = fetchingNewMessage || this.lastMessageIsNew
    return (
      <DisplayOrLoading
        display={!reloading || !!this.state.allMessages.length}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        <CardSection
          className='mb-3'
          label={
            <div className="row">
              <div className="col-auto"></div>
              <div className="col">{ this.category() }</div>
              <div className="col-auto">
                {
                  !reloading && (
                    <i className="material-icons clickable" onClick={this.forceGetMessages}>
                      refresh
                    </i>
                  )
                }
              </div>
            </div>
          }
          subLabel={
            reloading
              ? (
                  <div className="d-flex justify-content-center my-3">
                    <RunningDots className="la-dark la-2x" />
                  </div>
                )
              : (
                  <div className='row'>
                    <div className='col text-center'>
                      <TextField
                        name={`search[${this.type() || Math.random()}]`}
                        onChange={(e) => this.filter(e.target.value)}
                        className='form-control'
                        autoComplete='off'
                        skipExtras
                      />
                    </div>
                  </div>
                )
          }
          contentProps={{className: 'list-group'}}
        >
          {
            this.state.messages.map((m, k) => (
              <MessageInfo
                key={k}
                onSuccess={this.onSuccess}
                onCancel={() => !m.id && this.removeMessage(k)}
                reloading={reloading}
                {...m}
              />
            ))
          }
          {
            !!reloading && (
              <div className="list-group-item">
                <div className="d-flex justify-content-center my-3">
                  <RunningDots className="la-dark la-2x" />
                </div>
              </div>
            )
          }
          {
            !disableNewMessageButton && (
              <button className='btn-block btn-primary' onClick={this.newMessage}>
                Add {this.category()}
              </button>
            )
          }
        </CardSection>
      </DisplayOrLoading>
    )
  }
}
