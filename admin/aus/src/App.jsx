import React, { Suspense, Component } from 'react'
// import { BrowserRouter as Router, Link, Route, Switch, withRouter } from 'react-router-dom';
import { BrowserRouter as Router, Route, Switch, withRouter } from 'react-router-dom';
import { Link } from 'react-component-templates/components';
import PropTypes from 'prop-types';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import withNetworkStatus from 'components/network-detector'
import ErrorBoundary from 'components/error-boundary';
import MapContext from 'contexts/map'
import logo from 'assets/images/dus-logo.png';
import routes from 'routes'
import './App.css';

// suppress prop-types warning on Route component when using with React.lazy
// until react-router-dom@4.4.0 or higher version released
/* eslint-disable react/forbid-foreign-prop-types */
if(Route.propTypes) {
  Route.propTypes.component = PropTypes.oneOfType([
    Route.propTypes.component,
    PropTypes.object,
  ]);
}
/* eslint-enable react/forbid-foreign-prop-types */

class AppWrapper extends Component {
  render() {
    const { location: { pathname }, offline } = this.props

    return (
      <div className="App">
        <header className="App-header">
          {
            offline && (
              <h2 className="vw-100 bg-warning text-light">
                You are currently Working Offline
              </h2>
            )
          }
          <img src={logo} className="App-logo" alt="logo" />
          <p>
            Offline-Capable Web App for Australia
          </p>
          <nav className="nav nav-fill nav-tabs">
            <span className="nav-item">
              <Link to="/" className={`nav-link ${/^(\/aus)?\/?$/.test(String(pathname || '/')) ? 'active' : ''}`} href="#">Home</Link>
            </span>
            <span className="nav-item">
              <Link className={`nav-link ${(/^(\/aus)?\/airports/.test(pathname)) ? 'active' : ''}`} to="/airports">Intl Airports</Link>
            </span>
            <span className="nav-item">
              <Link className={`nav-link ${(/^(\/aus)?\/check-in/.test(pathname)) ? 'active' : ''}`} to="/check-in">Check In</Link>
            </span>
          </nav>
        </header>
        <div className="container">
          <div className="row">
            <div className="col-12 d-print-none form-group">
              <ErrorBoundary>
                <MapContext />
              </ErrorBoundary>
            </div>
            <div className="col">
              <Suspense fallback={<JellyBox className="page-loader" />}>
                <Switch>
                  {
                    routes.map((route, i) => <Route key={i} {...route}/>)
                  }
                </Switch>
              </Suspense>
            </div>
          </div>
        </div>
      </div>
    )
  }
}

const MainApp = withNetworkStatus(withRouter(AppWrapper))

export default function App() {
  return (
    <Router basename="/aus">
      <MainApp />
    </Router>
  )

}
