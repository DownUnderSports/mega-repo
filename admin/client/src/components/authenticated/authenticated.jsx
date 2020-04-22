import React, { Component } from 'react';
import AuthStatus from 'common/js/helpers/auth-status'
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import './authenticated.css'

const hasToken = () => !!AuthStatus.token

export default class Authenticated extends Component {

  constructor(props) {
    super(props)
    this.state = { authenticating: false, authenticated: hasToken() }
  }

  async componentDidMount() {
    if(!hasToken()) await this.retryAuth()
  }

  retryAuth = async (sendToServer = false) => {
    if(!this.state.authenticating) {
      this.setState({ authenticating: true }, async () => {
        try {
          await ((!navigator.onLine || (!sendToServer && AuthStatus.token)) ? Promise.resolve() : AuthStatus[(sendToServer ? 'sendToServer' : 'available')]())
        } catch(e) {
          console.log(e)
        }

        this.setState({ authenticating: false, authenticated: hasToken() })
      })
    }
  }

  retryAuthButtonClick = () => this.retryAuth(true)

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
              <button className="btn btn-block btn-primary" onClick={this.retryAuthButtonClick}>
                Retry
              </button>
            </DisplayOrLoading>
          </div>
        </div>
      </div>
    )
  }
}
