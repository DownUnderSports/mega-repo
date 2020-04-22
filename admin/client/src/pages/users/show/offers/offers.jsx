import React from 'react';
import Component from 'common/js/components/component/async'
import { Route, Switch } from 'react-router-dom';
import IndexPage from 'pages/users/show/offers/index'
import ShowPage from 'pages/users/show/offers/show'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { usersUrl } from 'components/user-info';

export default class UsersShowOffersPage extends Component {
  constructor(props) {
    super(props)
    this.state = {...this.state, offers: [] }
  }

  afterMount = async () => {
    if(!this.props.user || !this.props.user.dus_id) return await this.getUser()
    else return [
      await this.getOffers(),
    ]

  }

  getUser = async () => {
    if(!this.props.id) return false
    try {
      const result = await fetch(usersUrl.replace(':id', this.props.id)),
            retrieved = await result.json()

      if(this.props.afterFetch) this.props.afterFetch({user: retrieved})
      if(this._isMounted) return await this.getOffers()
    } catch(e) {
      console.error(e)
    }
    return true
  }

  getOffers = async () => {
    if(this._isMounted) {
      await this.setStateAsync({ loading: true })
      try {
        const result = await fetch(usersUrl.replace(':id', `${this.props.id}/offers`)),
              json = await result.json();

        if(this._isMounted) {
          return await this.setStateAsync({offers: json.offers || [], loading: false})
        }
      } catch(e) {
        console.error(e)
        if(this._isMounted){
          await this.setStateAsync({offers: [], loading: false})
        }
      }
    }
    return true
  }

  newOffer = () => ({
    amount: {},
    minimum: {},
    maximum: {},
    rules: []
  })

  afterFetch = (args) => this.props.afterFetch(args)

  findOffer = async (offerId) => {
    if((/new/i).test(`${offerId}`)) {
      const currentOffer = this.newOffer()
      return (await this.setStateAsync({ currentOffer })) && currentOffer
    }

    const currentOffer = this.state.offers.find(({id}) => (`${id}` === `${offerId}`))
    return currentOffer && (await this.setStateAsync({ currentOffer })) && currentOffer
  }

  showPage = (props) => (
    <ShowPage
      id={`${this.props.id}.offers.show`}
      key={`${this.props.id}.offers.${props.match.params.offerId}`}
      copyDusId={this.copyDusId}
      offers={this.state.offers}
      findOffer={this.findOffer}
      offer={this.state.currentOffer}
      indexUrl={this.props.match.url}
      getOffers={this.getOffers}
      {...this.props}
      {...props}
    />
  )

  indexPage = (props) => (
    <IndexPage
      id={`${this.props.id}.offers.index`}
      key={`${this.props.id}`}
      afterFetch={this.afterFetch}
      getOffers={this.getOffers}
      offers={this.state.offers}
      {...this.props}
      {...props}
    />
  )

  render() {
    const {
      // user: {
      //   dus_id,
      //   category,
      //   first,
      //   last,
      // },
      match: { path, params: { id } }, location: { pathname }
    } = this.props || {},
    url = path.replace(':id', `${id}`),
    isIndex = new RegExp(`${url}/?$`).test(pathname)

    return (
      <div key={id} className="Offers">
        <section className='offer-pages-wrapper' id='offer-pages-wrapper'>
          <header className='mb-3'>
            <Link to={`${url}${isIndex ? '/new' : ''}`} className={`btn btn-block ${isIndex ? 'btn-warning' : 'btn-info'}`}>
              { isIndex ? 'New Offer' : 'Back to List' }
            </Link>
          </header>
          <div className="main">
            <DisplayOrLoading display={!this.state.loading} >
              <Switch>
                <Route
                  path={`${url}/:offerId`}
                  render={this.showPage}
                />
                <Route render={this.indexPage} />
              </Switch>
            </DisplayOrLoading>
          </div>
        </section>
      </div>
    );
  }
}
