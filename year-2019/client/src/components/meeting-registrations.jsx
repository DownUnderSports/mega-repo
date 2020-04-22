import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import { DisplayOrLoading } from 'react-component-templates/components';
import canUseDOM from 'common/js/helpers/can-use-dom'
import MeetingRegistrationInfo from 'components/meeting-registration-info'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'


const registrationsUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/users/:user_id/meeting_registrations.json`

export default class MeetingRegistrations extends AsyncComponent {
  constructor(props) {
    super(props)
    this.state = { registrations: [], loading: true }
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.afterMount()
  }

  mainKey = () => this.props.id
  url = (id) => registrationsUrl.replace(':user_id', id)
  defaultValue = () => ({
    registrations: [],
  })

  capitalize(str) {
    return str[0].toUpperCase() + str.slice(1)
  }

  removeRegistration = (i) => {
    const {registrations = []} = this.state
    this.setState({registrations: [...registrations.slice(0, i), ...registrations.slice(i + 1)]})
  }

  addRegistration = () => this.setState({
    registrations: [
      ...this.state.registrations,
      { user_id: this.props.id }
    ]
  })

  render() {
    const {
      registrations = [],
      loading = false,
    } = this.state || {}

    return (
      <DisplayOrLoading
        display={!loading}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        {
          (registrations || []).map((r, k) => (
            <MeetingRegistrationInfo
              key={k}
              onSuccess={() => this.afterMount()}
              onCancel={ !r.id && (() => this.removeRegistration(k))}
              {...r}
            />
          ))
        }
        <button className='btn-block btn-primary' onClick={this.addRegistration}>
          Add Meeting
        </button>
      </DisplayOrLoading>
    );
  }
}
