import React from 'react';
import Component from 'common/js/components/component/async';
import { DisplayOrLoading, CardSection } from 'react-component-templates/components';
import OfferForm from 'common/js/forms/credit-offer-form';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box';
;

export default class UserOffersShowPage extends Component {
  constructor(props){
    super(props)
    this.action = `${this.props.location.pathname.replace('/new', '')}.json`
    this.state = { offer: {}, ...this.state }
  }

  afterMount = async () => {
    return await this.findOffer()
  }

  componentDidUpdate(prevProps) {
    if(!prevProps.offer || !this.props.offer || (this.props.match.params.offerId !== prevProps.match.params.offerId)) {
      this.findOffer()
    }
  }

  findOffer = async () => {
    const offer = await this.props.findOffer(this.props.match.params.offerId)
    return this._isMounted && offer && this.setStateAsync({ offer, loading: false })
  }

  render() {
    const { match: { params: { offerId } } } = this.props || {},
          { offer = {}, loading = true } = this.state || {}
    console.log(offer)

    return (
      <div key={offerId}>
        <DisplayOrLoading
          display={!loading}
          message='LOADING...'
          loadingElement={
            <JellyBox />
          }
        >
          <CardSection
            className='mb-3'
            label={offer.name || 'New Offer'}
            contentProps={{className: 'list-group'}}
          >
            <div className="list-group-item">
              <OfferForm
                key={offerId}
                {...offer}
                getOffers={this.props.getOffers}
                url={this.action}
                indexUrl={this.props.indexUrl}
                history={this.props.history}
              />
            </div>
          </CardSection>
        </DisplayOrLoading>
      </div>
    )
  }
}
