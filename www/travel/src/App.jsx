import React, { Suspense, Component } from 'react'
import { BrowserRouter as Router, Route, Switch, withRouter } from 'react-router-dom';
// import { Link } from 'react-component-templates/components';
import PropTypes from 'prop-types';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import withNetworkStatus from 'components/network-detector'
import logo from 'assets/images/dus-logo.png';
import routes from 'routes'
import ErrorBoundary from 'components/error-boundary';
import MapContext from 'contexts/map'
import Authenticated from 'components/authenticated'

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
  state = { offline: !window.navigator.onLine}

  componentDidMount() {
    this.handleConnectionChange();
    window.addEventListener('online', this.handleConnectionChange);
    window.addEventListener('offline', this.handleConnectionChange);
  }

  componentWillUnmount() {
    window.removeEventListener('online', this.handleConnectionChange);
    window.removeEventListener('offline', this.handleConnectionChange);
  }


  handleConnectionChange = () => {
    const condition = navigator.onLine ? 'online' : 'offline';
    if (condition === 'online') {
      const webPing = setInterval(
        () => {
          fetch('//google.com', {
            mode: 'no-cors',
            })
          .then(() => {
            this.setState({ offline: false }, () => {
              return clearInterval(webPing)
            });
          }).catch(() => this.setState({ offline: true }) )
        }, 2000);
      return;
    }

    return this.setState({ offline: true });
  }

  render() {
    // const { location: { pathname }, offline } = this.props
    const { offline } = this.props

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
            </span>
          </nav>
        </header>
        <Authenticated>
          <div className="container">
            <div className="row">
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
            <div className="row d-print-none">
              <div className="col-12">
                <ErrorBoundary>
                  <MapContext />
                </ErrorBoundary>
              </div>
            </div>
          </div>
        </Authenticated>
      </div>
    )
  }
}

const MainApp = withNetworkStatus(withRouter(AppWrapper))

export default function App() {
  return (
    <Router basename="/travel">
      <MainApp></MainApp>
    </Router>
  )

}
