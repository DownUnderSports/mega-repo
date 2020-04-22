import React from 'react';
import Component from 'common/js/components/component/async'
import { Route, Switch } from 'react-router-dom';
import IndexPage from 'pages/users/show/debits/index'
import ShowPage from 'pages/users/show/debits/show'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { usersUrl } from 'components/user-info';
//import authFetch from 'common/js/helpers/auth-fetch'

export default class UsersShowDebitsPage extends Component {
  constructor(props) {
    super(props)
    this.state = {...this.state, debits: [], baseDebits: [] }
  }

  afterMount = async () => {
    if(!this.props.user || !this.props.user.dus_id) return await this.getUser()
    else return [
      await this.getBaseDebits(),
      await this.getDebits(),
    ]

  }

  getUser = async () => {
    if(!this.props.id) return false
    try {
      const result = await fetch(usersUrl.replace(':id', this.props.id)),
            retrieved = await result.json()

      if(this.props.afterFetch) this.props.afterFetch({user: retrieved})
      if(this._isMounted) await this.getBaseDebits()
      if(this._isMounted) return await this.getDebits()
    } catch(e) {
      console.error(e)
    }
    return true
  }

  getBaseDebits = async () => {
    // this.setState({loading: true})
    try {
      const result = await fetch(`/admin/debits/base`),
            retrieved = await result.json()

      if(this._isMounted) {
        await this.setStateAsync({
          loading: false,
          baseDebits: retrieved.base_debits
        })
      }
    } catch(e) {
      console.error(e)
      if(this._isMounted) {
        await this.setStateAsync({
          loading: false,
        })
      }
      return false
    }
    return true
  }

  getDebits = async () => {
    if(this._isMounted) {
      await this.setStateAsync({ loading: true })
      try {
        const result = await fetch(usersUrl.replace(':id', `${this.props.id}/debits`)),
              json = await result.json();

        if(this._isMounted) {
          return await this.setStateAsync({debits: json.debits || [], loading: false})
        }
      } catch(e) {
        console.error(e)
        if(this._isMounted){
          await this.setStateAsync({debits: [], loading: false})
        }
      }
    }
    return true
  }

  newDebit = () => ({
    amount: {},
    base_debit: {
      amount: {}
    }
  })

  afterFetch = (args) => this.props.afterFetch(args)

  findDebit = async (debitId) => {
    if((/new/i).test(`${debitId}`)) {
      const currentDebit = this.newDebit()
      return (await this.setStateAsync({ currentDebit })) && currentDebit
    }

    const currentDebit = this.state.debits.find(({id, base_debit_id}) => (`${id}` === `${debitId}`) || (`${base_debit_id}` === `${debitId}`))
    return currentDebit && (await this.setStateAsync({ currentDebit })) && currentDebit
  }

  showPage = (props) => (
    <ShowPage
      id={`${this.props.id}.debits.show`}
      key={`${this.props.id}.debits.${props.match.params.debitId}`}
      copyDusId={this.copyDusId}
      baseDebits={this.state.baseDebits}
      debits={this.state.debits}
      findDebit={this.findDebit}
      debit={this.state.currentDebit}
      indexUrl={this.props.match.url}
      getDebits={this.getDebits}
      {...this.props}
      {...props}
    />
  )

  indexPage = (props) => (
    <IndexPage
      id={`${this.props.id}.debits.index`}
      key={`${this.props.id}`}
      afterFetch={this.afterFetch}
      getDebits={this.getDebits}
      debits={this.state.debits}
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
      <div key={id} className="Debits">
        <section className='debit-pages-wrapper' id='debit-pages-wrapper'>
          <header className='mb-3'>
            <Link to={`${url}${isIndex ? '/new' : ''}`} className={`btn btn-block ${isIndex ? 'btn-warning' : 'btn-info'}`}>
              { isIndex ? 'New Debit' : 'Back to List' }
            </Link>
          </header>
          <div className="main">
            <DisplayOrLoading display={!this.state.loading} >
              <Switch>
                <Route
                  path={`${url}/:debitId`}
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
