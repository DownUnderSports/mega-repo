import React, { Component } from 'react';
import { usersUrl } from 'components/user-info'
import DebitsList from 'components/debits-list'

export default class UserDebitsIndexPage extends Component {
  constructor(props) {
    super(props)
    this.debitUrl = usersUrl.replace(':id', `${this.props.id}/debits/:debit_id`).replace('.json', '')
  }

  render() {
    return (
      <div key={this.props.id}>
        <DebitsList debits={this.props.debits || []} url={this.debitUrl}/>
      </div>
    );
  }
}
