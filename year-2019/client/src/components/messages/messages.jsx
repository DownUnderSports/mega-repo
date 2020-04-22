import React, { Component } from 'react'
//import authFetch from 'common/js/helpers/auth-fetch'
import canUseDOM from 'common/js/helpers/can-use-dom'
import { DisplayOrLoading, CardSection } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import { Objected } from 'react-component-templates/helpers';
import MessageInfo from './message-info'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

import './messages.css'

const baseUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/users`

export default class Messages extends Component {

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

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.getMessages()
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

  getMessages = async () => {
    if(this._isMounted){
      this.setState({reloading: true})
      try {
        this.abortFetch()
        if(!this.props.id) throw new Error(`Messages (${this.type()}): No User ID`)
        this._fetchable = fetch(`${baseUrl}/${this.props.id}/messages.json?type=${this.type()}`, {timeout: 5000})
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
        console.log(m)
        for(let k in Objected.filterKeys(m, ['id', 'user_id', 'staff_id', 'type', 'categories'])) {
          if(m.hasOwnProperty(k) && reg.test(`${m[k] || ''}`)) return true
        }
        return false
      }) : [...this.state.allMessages]
    })
  }

  newMessage = async () => {
    this.setState({reloading: true})
    try {
      const result = await fetch(`${baseUrl}/${this.props.id || 0}/messages/new.json?type=${this.type()}`),
            retrieved = await result.json()

      this.setState({
        reloading: false,
        messages: [...this.state.messages, retrieved],
      })

    } catch(e) {
      this.setState({
        reloading: false,
        messages: [],
      })
    }
  }

  removeMessage = (i) => {
    const {messages = []} = this.state
    this.setState({messages: [...messages.slice(0, i), ...messages.slice(i + 1)]})
  }

  render() {
    return (
      <DisplayOrLoading
        display={!this.state.reloading}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        <CardSection
          className='mb-3'
          label={ this.category() }
          subLabel={
            <div className='row'>
              <div className='col text-center'>
                <TextField
                  name='dus_id'
                  onChange={(e) => this.filter(e.target.value)}
                  className='form-control'
                  autoComplete='off'
                  skipExtras
                />
              </div>
            </div>
          }
          contentProps={{className: 'list-group'}}
        >
          {
            this.state.messages.map((m, k) => (
              <MessageInfo
                key={k}
                onSuccess={() => this.getMessages()}
                onCancel={ !m.id && (() => this.removeMessage(k))}
                {...m}
              />
            ))
          }
          <button className='btn-block btn-primary' onClick={this.newMessage}>
            Add {this.category()}
          </button>
        </CardSection>
      </DisplayOrLoading>
    )
  }
}
