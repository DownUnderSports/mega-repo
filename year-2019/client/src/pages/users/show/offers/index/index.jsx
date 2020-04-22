import React, { Component } from 'react';
import { usersUrl } from 'components/user-info'
import OffersList from 'components/offers-list'

export default class UserOffersIndexPage extends Component {
  constructor(props) {
    super(props)
    this.offerUrl = usersUrl.replace(':id', `${this.props.id}/offers/:offer_id`).replace('.json', '')
  }

  render() {
    return (
      <div key={this.props.id}>
        <h2 className="text-center">
          Current Offers
        </h2>
        <OffersList offers={this.props.offers || []} url={this.offerUrl}/>
      </div>
    );
  }
}
