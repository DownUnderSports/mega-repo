import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import VerifyPassportForm from 'forms/verify-passport-form'
import { CardSection, Link } from 'react-component-templates/components';

const passportsUrl = "/admin/traveling/passports"

export default class TravelingPassportsShowPage extends AsyncComponent {
  get id(){
    try {
      const { match: { params: { id } } } = this.props
      return id
    } catch(_) {
      return 'new'
    }
  }

  constructor(props) {
    super(props)
    this.state = { user: {}, loading: true }
  }

  mainKey = () => this.id
  resultKey = () => 'user'
  url = (id) => `/admin/users/${id}.json`
  defaultValue = () => ({})

  afterFetch = ({user, skipTime = false}) => this.setStateAsync({
    loading: false,
    user: user || {},
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  backToIndex = () => this.props.history.push(passportsUrl)
  onFail = (msg) => {
    alert(msg)
    this.backToIndex()
  }

  render() {
    return (
      <CardSection
        className='mb-3'
        label={<span>Check Passport For: <Link to={`/admin/users/${this.id}`} target='_pp_user'>{this.state.user.first} {this.state.user.last} ({this.state.user.category}) - {this.id}</Link></span>}
      >
        <VerifyPassportForm
          dusId={this.id}
          key={this.id}
          onComplete={this.backToIndex}
          onFail={this.onFail}
          verify
        />
      </CardSection>
    );
  }
}
