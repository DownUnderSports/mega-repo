import React, { Component } from 'react';
import { usersUrl } from 'components/user-info'
import CreditsList from 'components/credits-list'

export default class UserCreditsIndexPage extends Component {
  constructor(props) {
    super(props)
    this.creditUrl = usersUrl.replace(':id', `${this.props.id}/credits/:credit_id`).replace('.json', '')
  }

  render() {
    return (
      <div key={this.props.id}>
        <h2 className="text-center">
          Assigned Credits
        </h2>
        <CreditsList credits={this.props.credits || []} url={this.creditUrl}/>
      </div>
    );
  }
}
