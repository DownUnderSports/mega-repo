import React from 'react';
import Component from 'common/js/components/component/async'
import { Route, Switch } from 'react-router-dom';
import IndexPage from 'pages/users/show/credits/index'
import ShowPage from 'pages/users/show/credits/show'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { usersUrl } from 'components/user-info';
//import authFetch from 'common/js/helpers/auth-fetch'

export default class UsersShowCreditsPage extends Component {
  constructor(props) {
    super(props)
    this.state = {...this.state, credits: [], offers: [] }
  }

  afterMount = async () => {
    if(!this.props.user || !this.props.user.dus_id) return await this.getUser()
    else return [
      await this.getCredits(),
    ]

  }

  getUser = async () => {
    if(!this.props.id) return false
    try {
      const result = await fetch(usersUrl.replace(':id', this.props.id)),
            retrieved = await result.json()

      if(this.props.afterFetch) this.props.afterFetch({user: retrieved})
      if(this._isMounted) return await this.getCredits()
    } catch(e) {
      console.error(e)
    }
    return true
  }

  getCredits = async () => {
    if(this._isMounted) {
      await this.setStateAsync({ loading: true })
      try {
        const result = await fetch(usersUrl.replace(':id', `${this.props.id}/credits`)),
              json = await result.json();

        if(this._isMounted) {
          return await this.setStateAsync({
            credit_categories: json.credit_categories || [],
            credits: json.credits || [],
            offers: json.offers || [],
            loading: false
          })
        }
      } catch(e) {
        console.error(e)
        if(this._isMounted){
          await this.setStateAsync({credit_categories: [], credits: [], offers: [], loading: false})
        }
      }
    }
    return true
  }

  newCredit = () => ({
    amount: {},
  })

  afterFetch = (args) => this.props.afterFetch(args)

  findCredit = async (creditId) => {
    if((/new/i).test(`${creditId}`)) {
      const currentCredit = this.newCredit()
      return (await this.setStateAsync({ currentCredit })) && currentCredit
    }

    const currentCredit = this.state.credits.find(({id}) => (`${id}` === `${creditId}`))
    return currentCredit && (await this.setStateAsync({ currentCredit })) && currentCredit
  }

  showPage = (props) => (
    <ShowPage
      id={`${this.props.id}.credits.show`}
      key={`${this.props.id}.credits.${props.match.params.creditId}`}
      copyDusId={this.copyDusId}
      credits={this.state.credits}
      categories={this.state.credit_categories}
      findCredit={this.findCredit}
      credit={this.state.currentCredit}
      indexUrl={this.props.match.url}
      getCredits={this.getCredits}
      {...this.props}
      {...props}
    />
  )

  indexPage = (props) => (
    <IndexPage
      id={`${this.props.id}.credits.index`}
      key={`${this.props.id}`}
      afterFetch={this.afterFetch}
      getCredits={this.getCredits}
      credits={this.state.credits}
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
      <div key={id} className="Credits">
        <section className='credit-pages-wrapper' id='credit-pages-wrapper'>
          <header className='mb-3'>
            <Link to={`${url}${isIndex ? '/new' : ''}`} className={`btn btn-block ${isIndex ? 'btn-warning' : 'btn-info'}`}>
              { isIndex ? 'New Credit' : 'Back to List' }
            </Link>
          </header>
          <div className="main">
            <DisplayOrLoading display={!this.state.loading} >
              <Switch>
                <Route
                  path={`${url}/:creditId`}
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
