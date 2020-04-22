import React from 'react'
import Component from 'common/js/components/component'
import EventRegistrationForm from 'common/js/forms/event-registration-form'
import { CardSection } from 'react-component-templates/components';

export default class EventRegistrationPage extends Component {
  constructor(props){
    super(props)
    this.state = {}
  }

  async componentDidMount(){
    await this.fetchUser()
  }

  fetchUser = async () => {
    const { match: { params: { userId } } } = this.props,
          fetchUrl = `/api/event_registrations/${userId}`

    if(userId) {
      let val = {}
      try {
        const res = await fetch(fetchUrl)
        val = await res.json() || {}
      } catch(_) {
        val = {}
      }
      return await this.setStateAsync(val)
    }
  }

  setSportTitle = (sportTitle = "") => this.setState({ sportTitle })
  backToChecklist = () => this.props.history.push(`/departure-checklist/${this.props.match.params.userId}`)

  render() {
    return (
      <CardSection
        className="EventsPage my-4"
        label={<div>
          {this.state.sportTitle} Event Registration
          {this.state.dus_id && `: ${this.state.name} (${this.state.dus_id})`}
        </div>}
        contentProps={{className: 'list-group'}}
      >
        {
          this.state.dus_id ? (
            <EventRegistrationForm path={this.props.match.url} id={this.props.match.params.userId} setSportTitle={this.setSportTitle} {...this.state} onSuccess={this.backToChecklist} />
          ) : (
            <div className="list-group-item">
              Please contact a Down Under Sports representative for your event registration link.
              <ul>
                <li>Email: <a href="mailto:mail@downundersports.com">mail@downundersports.com</a></li>
                <li>Phone: <a href="tel:435-753-4732">435-753-4732</a></li>
              </ul>
            </div>
          )
        }
      </CardSection>
    );
  }
}
