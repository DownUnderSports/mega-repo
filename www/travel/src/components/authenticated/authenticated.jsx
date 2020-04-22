import React, { Component } from 'react';
import AuthStatus from 'helpers/auth-status'
import { DisplayOrLoading } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import dusIdFormat, { userIsValid } from 'helpers/dus-id-format'
import './authenticated.css'

const isAuthenticated = () => !!AuthStatus.dusId || !window.navigator.onLine

export default class Authenticated extends Component {
  get allowDusId() {
    return true
  }

  get dusIdFirst() {
    return true
  }

  constructor(props) {
    super(props)
    this.state = { authenticating: false, authenticated: isAuthenticated(), dusId: AuthStatus.dusId }
  }

  async componentDidMount() {
    if(!isAuthenticated()) await this.retryAuth()
  }

  retryAuth = async (sendToServer = false) => {
    if(!this.state.authenticating) {
      this.setState({ authenticating: true }, async () => {
        try {
          await ((!navigator.onLine || (!sendToServer && AuthStatus.dusId)) ? Promise.resolve() : AuthStatus[(sendToServer ? 'sendToServer' : 'available')]())
        } catch(e) {
          console.log(e)
        }

        this.setState({ authenticating: false, authenticated: isAuthenticated() || (!!this.allowDusId && !!AuthStatus.dusId) })
      })
    }
  }

  retryAuthButtonClick = () => this.retryAuth(true)

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  validUser = async (dusId) => {
    dusId = dusIdFormat(String(dusId || ''))

    this.setState({ dusId, failed: false, authenticating: dusId.length > 6 })

    this.abortFetch()
    try {
      dusId = await userIsValid(dusId || '', this)
      if(dusId) {
        AuthStatus.dusId = dusId
        this.setState({ authenticated: true, authenticating: false })
      } else {
        AuthStatus.dusId = ''
      }
    } catch(e) {
      console.log(e)
      await new Promise(r => this.setState({ authenticated: false, failed: true, authenticating: false }, r));
      if(this.dusIdFirst) return await this.retryAuth()
      return false
    }
  }

  onDusIdChange = (ev) => this.validUser(ev.currentTarget.value)

  render() {
    return this.state.authenticated ? (
      this.props.children
    ) : (
      <div className="container">
        <div className="row">
          <div className="col">
            <h3>Authorize Access</h3>
          </div>
          <div className="col-12">
            <DisplayOrLoading
              display={!this.state.authenticating}
              message='AUTHORIZING...'
              loadingElement={
                <JellyBox className="authenticated-jelly-box" />
              }
            >
              <div className='row'>
                <div className="col-12 form-group">
                  <TextField
                    name='dus_id'
                    label={'Enter your DUS ID to Continue'}
                    onChange={this.onDusIdChange}
                    value={this.state.dusId || ''}
                    caretIgnore='-'
                    className='form-control'
                    autoComplete='off'
                    placeholder='AAA-AAA'
                    pattern="[a-zA-Z]*"
                    looseCasing
                  />
                </div>
                {
                  this.state.failed && (
                    <div className="col-12">
                      <div className="alert alert-danger">
                        Failed to Authenticate
                      </div>
                    </div>
                  )
                }
              </div>
            </DisplayOrLoading>
          </div>
        </div>
      </div>
    )
  }
}
