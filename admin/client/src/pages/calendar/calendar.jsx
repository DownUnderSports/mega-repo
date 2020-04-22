import React, { Component } from 'react'
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { CurrentUser } from 'common/js/contexts/current-user'

export default class CalendarPage extends Component {
  static contextType = CurrentUser.Context

  state = {
    loading: true,
    errors: null,
  }

  get currentEmail() {
    try {
      return this.context.currentUserState.attributes.email
    } catch(err) {
      console.error(err)
      return ''
    }

  }

  get calendarSrc() {
    return this.currentEmail
      ? `${encodeURIComponent(this.currentEmail)}&src=${encodeURIComponent('mail@downundersports.com')}`
      : `src=${encodeURIComponent('mail@downundersports.com')}`
  }

  async componentDidMount() {
    await this.getEmail()
  }

  getEmail = async () => {
    try {
      this.setState({ loading: true })
      await this.context.currentUserState.loaded ? Promise.resolve() : this.context.currentUserActions.getCurrentUser()
      console.log(this.context.currentUserState)
      this.setState({ loading: false })
    } catch(err) {
      console.error(err)
      await (new Promise(async r => {
        try {
          this.setState({ errors: (await err.response.json()).errors }, r)
        } catch(e) {
          this.setState({ errors: [ err.toString() ] }, r)
        }
      }))

      this.setState({ loading: false })
    }
  }

  renderErrors = () =>
    !!this.state.errors && (
      <div className="alert alert-danger form-group" role="alert">
        {
          this.state.errors.map((v, k) => (
            <div className='row' key={k}>
              <div className="col">
                { v }
              </div>
            </div>
          ))
        }
      </div>
    )

  render(){
    return <section className="Calendar">
      <header className="form-group">
        <h3>
          My Calendar
        </h3>
      </header>
      { this.renderErrors() }
      <div className="row form-group">
        <div className="col">
          <DisplayOrLoading
            display={!this.state.loading}
            message='LOADING...'
            loadingElement={
              <JellyBox className="authenticated-jelly-box" />
            }
          >
            <div
              class="col-12"
              style={{ height: '90vh' }}
            >
              <iframe
                key={this.encodedEmail}
                title="my_calendar"
                src={`https://calendar.google.com/calendar/embed?${this.calendarSrc}&ctz=America%2FDenver&mode=MONTH&wkst=1&showPrint=0`}
                style={{border: 0}}
                width="100%"
                height="100%"
                frameBorder="0"
                scrolling="no"
              />
            </div>
          </DisplayOrLoading>
        </div>
      </div>
    </section>
  }
}
