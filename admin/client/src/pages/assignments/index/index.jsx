import React, { Suspense, lazy } from 'react';
import Component from 'common/js/components/component'
import { Route, Switch } from 'react-router-dom';
import { Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import './index.css'

const RespondsPage = lazy(() => import(/* webpackChunkName: "assignments-responds-page", webpackPrefetch: true */ 'pages/assignments/responds'))
const TravelersPage = lazy(() => import(/* webpackChunkName: "assignments-travelers-page", webpackPrefetch: true */ 'pages/assignments/travelers'))
const CleanupPage = lazy(() => import(/* webpackChunkName: "assignments-cleanup-page", webpackPrefetch: true */ 'pages/assignments/cleanup'))
const RecapsPage = lazy(() => import(/* webpackChunkName: "assignments-recaps-page", webpackPrefetch: true */ 'pages/assignments/recaps'))

const pages = [ 'responds', 'travelers', 'cleanup', 'recaps' ]

export default class AssignmentsPage extends Component {
  respondsPage = (props) => (
    <RespondsPage
      key="responds"
      {...this.props}
      {...props}
    />
  )

  travelersPage = (props) => (
    <TravelersPage
      key="travelers"
      {...this.props}
      {...props}
    />
  )

  cleanupPage = (props) => (
    <CleanupPage
      key="cleanup"
      {...this.props}
      {...props}
    />
  )

  recapsPage = (props) => (
    <RecapsPage
      key="recaps"
      {...this.props}
      {...props}
    />
  )

  active = (url, pathname, key = 'responds') =>
    new RegExp(`${url}${key === 'responds' ? `(/|/${key})?` : `/${key}`}/?(\\?.*)?$`).test(pathname) ? 'active' : ''

  render() {
    const { match: { path, params: { id } }, location: { pathname } } = this.props,
          url = path.replace(/:id(\(.*?\))?/, `${id}`)

    return (
      <section className="Assignments row">
        <header className="col-12 text-center">
          <h3>Assignments</h3>
          <nav className="nav sports-nav nav-tabs justify-content-end">
            <input type="checkbox" id="assignments-page-nav-trigger" className="page-nav-trigger" />
            <label htmlFor="page-nav-trigger" className="nav-item nav-link d-md-none">
              <span><span></span></span>
              Sub Pages
            </label>
            {
              pages.map(key => (
                <Link
                  key={key}
                  to={`${url}/${key}`}
                  className={`nav-item nav-link ${this.active(url, pathname, key)}`}
                >
                  { key.capitalize() }
                </Link>
              ))
            }
          </nav>
        </header>
        <div className="col-12">
          <Suspense fallback={<JellyBox className="page-loader" />}>
            <Switch>
              {
                pages.map(key => (
                  <Route
                    key={key}
                    path={`${url}/${key}`}
                    render={this[`${key}Page`]}
                  />
                ))
              }
              <Route render={this.respondsPage} />
            </Switch>
          </Suspense>
        </div>
      </section>
    );
  }
}
