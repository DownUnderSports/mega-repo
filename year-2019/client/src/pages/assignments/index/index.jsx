import React, { Suspense, lazy } from 'react';
import Component from 'common/js/components/component'
import { Route, Switch } from 'react-router-dom';
import { Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import './index.css'

const RespondsPage = lazy(() => import(/* webpackChunkName: "assignments-responds-page", webpackPrefetch: true */ 'pages/assignments/responds'))

export default class AssignmentsPage extends Component {
  respondsPage = (props) => (
    <RespondsPage
      key="responds"
      {...this.props}
      {...props}
    />
  )

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
            <Link key="responds" to={`${url}/responds`} className={`nav-item nav-link ${new RegExp(`${url}(/|/responds)?(\\?.*)?$`).test(pathname) ? 'active' : ''}`}>
              Responds
            </Link>
          </nav>
        </header>
        <div className="main col-12">
          <Suspense fallback={<JellyBox className="page-loader" />}>
            <Switch>
              <Route render={this.respondsPage} />
            </Switch>
          </Suspense>
        </div>
      </section>
    );
  }
}
