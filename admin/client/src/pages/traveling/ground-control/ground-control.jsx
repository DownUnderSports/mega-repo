import React, { Component, Suspense, lazy } from 'react';
import { Route, Switch }                    from 'react-router-dom';
import { Link }                             from 'react-component-templates/components';
import JellyBox                             from 'load-awesome-react-components/dist/square/jelly-box'

const url = '/admin/traveling/ground_control'

const BusPages = lazy(() => import(/* webpackChunkName: "traveling-ground-control-buses-page", webpackPreload: true */ 'pages/traveling/ground-control/buses'))
const CompetingTeamPages = lazy(() => import(/* webpackChunkName: "traveling-ground-control-competing-teams-page", webpackPreload: true */ 'pages/traveling/ground-control/competing-teams'))
const HotelPages = lazy(() => import(/* webpackChunkName: "traveling-ground-control-hotels-page", webpackPreload: true */ 'pages/traveling/ground-control/hotels'))

export default class TravelingGroundControlPage extends Component {

  render() {
    const { location: { pathname } } = this.props

    return (
      <div className="GroundControl row">
        <div className="col-12 text-center">
          <section className='sub-page-wrapper' id='traveling-pages-wrapper'>
            <header>
              <nav className="nav nav-tabs justify-content-end m-0">
                <input type="checkbox" id="ground-control-page-nav-trigger" className="nav-trigger" />
                <label htmlFor="ground-control-page-nav-trigger" className="nav-trigger nav-item nav-link d-md-none">
                  <span><span></span></span>
                  Sub Pages
                </label>
                <Link
                  key="traveling.ground-control.buses"
                  to={`${url}/buses`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/ground_control(/buses.*|/?$)`).test(pathname) ? 'active bg-light' : ''}`}
                >
                  Buses
                </Link>
                <Link
                  key="traveling.ground-control.competing-teams"
                  to={`${url}/competing_teams`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/ground_control/competing_teams/?`).test(pathname) ? 'active bg-light' : ''}`}
                >
                  Competing Teams
                </Link>
                <Link
                  key="traveling.ground-control.hotels"
                  to={`${url}/hotels`}
                  className={`nav-item nav-link ${new RegExp(`/admin/traveling/ground_control/hotels/?`).test(pathname) ? 'active bg-light' : ''}`}
                >
                  Hotels
                </Link>
              </nav>
            </header>
            <div className="main">
              <Suspense fallback={<JellyBox className="page-loader" />}>
                <Switch>
                  <Route
                    path={`${url}/competing_teams`}
                    component={CompetingTeamPages}
                  />
                  <Route
                    path={`${url}/hotels`}
                    component={HotelPages}
                  />
                  <Route component={BusPages} />
                </Switch>
              </Suspense>
            </div>
          </section>
        </div>
      </div>
    );
  }
}
