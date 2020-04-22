import React, { Suspense, lazy } from 'react';
import Component from 'common/js/components/component'
import { Route, Switch } from 'react-router-dom';
import { Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import CopyClip from 'common/js/helpers/copy-clip'
import './show.css'

const InfoPage = lazy(() => import(/* webpackChunkName: "user-info-page" */ 'pages/users/show/info'))
const CallsPage = lazy(() => import(/* webpackChunkName: "user-calls-page" */ 'pages/users/show/calls'))
const AssignmentsPage = lazy(() => import(/* webpackChunkName: "user-assignments-page" */ 'pages/users/show/assignments'))
const OffersPage = lazy(() => import(/* webpackChunkName: "user-offers-page" */ 'pages/users/show/offers'))
const CreditsPage = lazy(() => import(/* webpackChunkName: "user-credits-page" */ 'pages/users/show/credits'))
const DebitsPage = lazy(() => import(/* webpackChunkName: "user-debits-page" */ 'pages/users/show/debits'))

export default class UsersShowPage extends Component {
  constructor(props) {
    super(props)
    this.state = { user: { }, loading: true }
  }

  get url() {
    return this._url || (this._url = `${window.location.origin.replace(/admin\.d/, 'authorize.d').replace(/:(\d)000$/, ":$1100")}${this.currentPath.url}`)
  }

  get currentPath() {
    try {
      const { match: { path, params: { id } }, location: { pathname } } = this.props

      return this._currentPath || (this._currentPath = {
        path,
        id,
        pathname,
        url: path.replace(/:id(\(.*?\))?/, `${/admin/.test(path) ? '' : 'admin/'}${/users/.test(path) ? '' : 'users/'}${id}`)
      })
    } catch(_) {
      return {}
    }
  }

  componentDidUpdate() {
    this._currentPath = ''
    this._url = ''
  }

  afterFetch = ({user, skipTime = false}) => this.setStateAsync({
    loading: false,
    user: user || {},
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  afterMeetingFetch = () => this.setStateAsync({
    lastFetch: +(new Date())
  })

  copyDeposit = () => {
    const {
      user: {
        dus_id,
        traveler = false,
      },
    } = this.state

    CopyClip.prompted(`https://www.downundersports.com/${traveler ?  '' : 'deposit/'}${dus_id}`)
  }

  copyInfoVideo = () => {
    CopyClip.prompted(`https://www.downundersports.com/videos/i/${this.state.user.dus_id}`)
  }

  copyDusId = () => {
    const {
      user: {
        dus_id,
      },
    } = this.state

    CopyClip.prompted(`${dus_id}`)
  }

  viewStatement = () =>
    this.openLink(this.state.user.statement_link, '_view_statement')

  viewChecklist = () => {
    console.log(this.state.user)
    return this.openLink(this.state.user.checklist_link, '_view_checklist')
  }

  viewOverPayment = () =>
    this.openLink(this.state.user.over_payment_link, '_over_payment_form')

  openLink = (link, key) => {
    const w = window.open()
    w.name = key
    w.opener = null
    w.referrer = null
    w.location = link
  }

  viewAuthPage = (page) => {
    const w = window.open()
    w.name = '_view_auth_page'
    w.opener = null
    w.referrer = null
    w.location = `${this.url}/${page}`
  }

  infoPage = () => (
    <InfoPage
      id={this.getIdProp()}
      key={`${this.getIdProp()}.info`}
      afterFetch={this.afterFetch}
      afterMeetingFetch={this.afterMeetingFetch}
      copyDeposit={this.copyDeposit}
      copyInfoVideo={this.copyInfoVideo}
      copyDusId={this.copyDusId}
      viewChecklist={this.viewChecklist}
      viewStatement={this.viewStatement}
      viewOverPayment={this.viewOverPayment}
      viewAuthPage={this.viewAuthPage}
      {...this.state}
    />
  )

  callsPage = () => (
    <CallsPage
      id={this.getIdProp()}
      key={`${this.getIdProp()}.info`}
      afterFetch={this.afterFetch}
      copyDeposit={this.copyDeposit}
      copyInfoVideo={this.copyInfoVideo}
      copyDusId={this.copyDusId}
      {...this.state}
    />
  )

  assignmentsPage = (props) => (
    <AssignmentsPage
      id={this.getIdProp()}
      key={`${this.getIdProp()}.assignments`}
      afterFetch={this.afterFetch}
      {...props}
      {...this.state}
    />
  )

  debitsPage = (props) => (
    <DebitsPage
      id={this.getIdProp()}
      key={`${this.getIdProp()}.debits`}
      afterFetch={this.afterFetch}
      {...props}
      {...this.state}
    />
  )

  creditsPage = (props) => (
    <CreditsPage
      id={this.getIdProp()}
      key={`${this.getIdProp()}.credits`}
      afterFetch={this.afterFetch}
      {...props}
      {...this.state}
    />
  )

  offersPage = (props) => (
    <OffersPage
      id={this.getIdProp()}
      key={`${this.getIdProp()}.offers`}
      afterFetch={this.afterFetch}
      {...props}
      {...this.state}
    />
  )

  getIdProp = () => {
    return ((this.props.match && this.props.match.params) || {}).id
  }

  activeClass(url, pathname, key) {
    return new RegExp(`${url}/${key}`).test(pathname) ? 'active' : ''
  }

  render() {
    const {
      user: {
        dus_id,
        category,
        first,
        last,
        traveler = false,
        invite_rule,
        team,
        is_athlete,
        athlete_grad
      },
    } = this.state,
    { id, pathname, url } = this.currentPath,
    { name } = (team || {}),
    srOnly = (invite_rule || {}).grad_year === 2020,
    underAge = srOnly && is_athlete && (!athlete_grad || (athlete_grad > 2020))

    return (
      <div key={id} className="Users ShowPage">
        {
          !!dus_id && (
            <h1 className={`text-center below-header clickable copyable ${underAge ? 'bg-warning text-black' : ''}`} onClick={this.copyDusId}>
              <span>
                { first } { last } ({ dus_id }) - { category }{ !!name && ` - ${name}` }{
                  traveler && (
                    <> - {traveler.cancel_date ? `Canceled: ${traveler.cancel_date}` : 'Active'}</>
                  )
                }{
                  srOnly && (
                    <> - SR ONLY STATE</>
                  )
                }
              </span>
            </h1>
          )
        }
        <section className='user-pages-wrapper sub-page-wrapper' id='user-pages-wrapper'>
          <header>
            <nav className="nav sports-nav nav-tabs justify-content-end">
              <input type="checkbox" id="user-page-nav-trigger" className="nav-trigger" />
              <label htmlFor="user-page-nav-trigger" className='nav-trigger nav-item nav-link d-md-none'>
                <span><span></span></span>
                Sub Pages
              </label>
              <Link key={`${id}.info`} to={`${url}`} className={`nav-item nav-link ${this.activeClass(url, pathname, '?$')}`}>
                Info
              </Link>
              <Link key={`${id}.assignments`} to={`${url}/assignments`} className={`nav-item nav-link ${this.activeClass(url, pathname, 'assignments')}`}>
                Assignments
              </Link>
              {
                traveler && (
                  <>
                    <Link key={`${id}.calls`} to={`${url}/calls`} className={`nav-item nav-link ${this.activeClass(url, pathname, 'calls')}`}>
                      Calls
                    </Link>
                    <Link key={`${id}.credits`} to={`${url}/credits`} className={`nav-item nav-link ${this.activeClass(url, pathname, 'credits')}`}>
                      Credits
                    </Link>
                    <Link key={`${id}.debits`} to={`${url}/debits`} className={`nav-item nav-link ${this.activeClass(url, pathname, 'debits')}`}>
                      Debits
                    </Link>
                  </>
                )
              }
              <Link key={`${id}.offers`} to={`${url}/offers`} className={`nav-item nav-link ${this.activeClass(url, pathname, 'offers')}`}>
                Offers
              </Link>
            </nav>
          </header>
          <Suspense fallback={<JellyBox className="page-loader" />}>
            <Switch>
              <Route
                path={`${url}/assignments`}
                render={this.assignmentsPage}
              />
              <Route
                path={`${url}/calls`}
                render={this.callsPage}
              />
              <Route
                path={`${url}/credits`}
                render={this.creditsPage}
              />
              <Route
                path={`${url}/debits`}
                render={this.debitsPage}
              />
              <Route
                path={`${url}/offers`}
                render={this.offersPage}
              />
              <Route render={this.infoPage} />
            </Switch>
          </Suspense>
        </section>
      </div>
    );
  }
}
