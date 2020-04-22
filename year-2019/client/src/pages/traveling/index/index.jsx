import React, { Component, Suspense, lazy } from 'react';
import { Route, Switch } from 'react-router-dom';
import { Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { TravelingGCMRegistrationsIndexPage, TravelingGCMRegistrationsShowPage } from 'pages/traveling/gcm-registrations'
import { TravelingPassportsIndexPage, TravelingPassportsShowPage } from 'pages/traveling/passports'
const url = '/admin/traveling'

const TravelingEventRegistrationsPage = lazy(() => import(/* webpackChunkName: "traveling-event-registrations-page", webpackPreload: true */ 'pages/traveling/event-registrations'))
const TravelingEventResultsPage = lazy(() => import(/* webpackChunkName: "traveling-event-results-page", webpackPreload: true */ 'pages/traveling/event-results'))
const TravelingFlightsPage = lazy(() => import(/* webpackChunkName: "traveling-flights-page", webpackPreload: true */ 'pages/traveling/flights'))
const TravelingGroundControlPage = lazy(() => import(/* webpackChunkName: "traveling-flights-page", webpackPreload: true */ 'pages/traveling/ground-control'))

export default class TravelingIndexPage extends Component {

  render() {
    const { location: { pathname } } = this.props

    return (
      <div className="Traveling IndexPage row">
        <div className="col-12 text-center">
          <section className='sub-page-wrapper' id='traveling-pages-wrapper'>
            <header>
              <nav className="nav sports-nav nav-tabs justify-content-end">
                <input type="checkbox" id="traveling-page-nav-trigger" className="nav-trigger" />
                <label htmlFor="traveling-page-nav-trigger" className="nav-trigger nav-item nav-link d-md-none">
                  <span><span></span></span>
                  Sub Pages
                </label>
                <Link
                  key="traveling.flights"
                  to={`${url}/flights`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling(/flights.*|/?$)`).test(pathname) ? 'active' : ''}`}
                >
                  Flights
                </Link>
                <Link
                  key="traveling.event-registrations"
                  to={`${url}/event_registrations`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/event_registrations`).test(pathname) ? 'active' : ''}`}
                >
                  Event Registrations
                </Link>
                <Link
                  key="traveling.event-results"
                  to={`${url}/event_results`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/event_results`).test(pathname) ? 'active' : ''}`}
                >
                  Event Results
                </Link>
                <Link
                  key="traveling.gcm-registrations"
                  to={`${url}/gcm_registrations`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/gcm_registrations`).test(pathname) ? 'active' : ''}`}
                >
                  GCM Registrations
                </Link>
                <Link
                  key="traveling.ground-control"
                  to={`${url}/ground_control`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/ground_control`).test(pathname) ? 'active' : ''}`}
                >
                  Ground Control
                </Link>
                <Link
                  key="traveling.passports"
                  to={`${url}/passports`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/passports`).test(pathname) ? 'active' : ''}`}
                >
                  Passport Checks
                </Link>
              </nav>
            </header>
            <div className="main">
              <Suspense fallback={<JellyBox className="page-loader" />}>
                <Switch>
                  <Route
                    path={`${url}/event_registrations`}
                    component={TravelingEventRegistrationsPage}
                  />
                  <Route
                    path={`${url}/event_results`}
                    component={TravelingEventResultsPage}
                  />
                  <Route
                    path={`${url}/gcm_registrations/:id`}
                    component={TravelingGCMRegistrationsShowPage}
                  />
                  <Route
                    path={`${url}/gcm_registrations`}
                    component={TravelingGCMRegistrationsIndexPage}
                  />
                  <Route
                    path={`${url}/ground_control`}
                    component={TravelingGroundControlPage}
                  />
                  <Route
                    path={`${url}/passports/:id`}
                    component={TravelingPassportsShowPage}
                  />
                  <Route
                    path={`${url}/passports`}
                    component={TravelingPassportsIndexPage}
                  />
                  <Route component={TravelingFlightsPage} />
                </Switch>
              </Suspense>
            </div>
          </section>
        </div>
      </div>
    );
  }
}
