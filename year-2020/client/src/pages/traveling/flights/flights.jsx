import React, { Component, Suspense, lazy } from 'react';
import { Route, Switch }                    from 'react-router-dom';
import { Link }                             from 'react-component-templates/components';
import JellyBox                             from 'load-awesome-react-components/dist/square/jelly-box'

const url = '/admin/traveling/flights'

const ListPage      = lazy(() => import(/* webpackChunkName: "traveling-flights-list-page", webpackPreload: true */ 'pages/traveling/flights/list'))
const AirportPages  = lazy(() => import(/* webpackChunkName: "traveling-flights-airports-page", webpackPreload: true */ 'pages/traveling/flights/airports'))
const SchedulePages = lazy(() => import(/* webpackChunkName: "traveling-flights-schedules-page", webpackPreload: true */ 'pages/traveling/flights/schedules'))

export default class TravelingFlightsPage extends Component {

  render() {
    const { location: { pathname } } = this.props

    return (
      <div className="Flights row">
        <div className="col-12 text-center">
          <section className='sub-page-wrapper' id='traveling-pages-wrapper'>
            <header>
              <nav className="nav sports-nav nav-tabs justify-content-end m-0">
                <input type="checkbox" id="flights-page-nav-trigger" className="nav-trigger" />
                <label htmlFor="flights-page-nav-trigger" className="nav-trigger nav-item nav-link d-md-none">
                  <span><span></span></span>
                  Sub Pages
                </label>
                <Link
                  key={`traveling.flights.airports`}
                  to={`${url}/airports`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/flights/airports`).test(pathname) ? 'active bg-light' : ''}`}
                >
                  Airports
                </Link>
                <Link
                  key={`traveling.flights.schedules`}
                  to={`${url}/schedules`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling(/flights(?:/schedules)?)?/?$`).test(pathname) ? 'active bg-light' : ''}`}
                >
                  Schedules
                </Link>
                <Link
                  key={`traveling.flights.list`}
                  to={`${url}/list`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/flights/list`).test(pathname) ? 'active bg-light' : ''}`}
                >
                  List
                </Link>
              </nav>
            </header>
            <div className="main">
              <Suspense fallback={<JellyBox className="page-loader" />}>
                <Switch>
                  <Route
                    path={`${url}/airports`}
                    component={AirportPages}
                  />
                  <Route
                    path={`${url}/list`}
                    component={ListPage}
                  />
                  <Route component={SchedulePages} />
                </Switch>
              </Suspense>
            </div>
          </section>
        </div>
      </div>
    );
  }
}
