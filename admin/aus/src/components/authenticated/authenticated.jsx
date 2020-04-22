import React, { Component } from 'react';
import AuthStatus from 'helpers/auth-status'
import { DisplayOrLoading } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import dusIdFormat, { userIsValid } from 'helpers/dus-id-format'
import './authenticated.css'

const hasToken = (allowDusId) => !!AuthStatus.token || (!!allowDusId && AuthStatus.dusId) || !window.navigator.onLine

export default class Authenticated extends Component {
  get allowDusId() {
    return !!this.props.allowDusId || !!this.props.dusIdFirst
  }

  get dusIdFirst() {
    return !!this.props.dusIdFirst
  }

  constructor(props) {
    super(props)
    this.state = { authenticating: false, authenticated: hasToken(props.dusIdFirst), dusId: AuthStatus.dusId }
  }

  async componentDidMount() {
    if(!this.hasToken() && !this.dusIdFirst) await this.retryAuth()
  }

  hasToken = () => hasToken(this.dusIdFirst)

  retryAuth = async (sendToServer = false) => {
    console.log(sendToServer)
    if(!this.state.authenticating) {
      this.setState({ authenticating: true }, async () => {
        try {
          await ((!navigator.onLine || (!sendToServer && AuthStatus.token)) ? Promise.resolve() : AuthStatus[(sendToServer ? 'sendToServer' : 'available')]())
        } catch(e) {
          console.log(e)
        }

        this.setState({ authenticating: false, authenticated: this.hasToken() || (!!this.allowDusId && !!AuthStatus.dusId) })
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
            {
              this.allowDusId ? (
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
              ) : (
                <button className="btn btn-block btn-primary" onClick={this.retryAuthButtonClick}>
                  Retry
                </button>
              )
            }
          </DisplayOrLoading>
        </div>
      </div>
    )
  }
}
