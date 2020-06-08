import React, { Component, Suspense, lazy } from 'react';
import { Route, Switch } from 'react-router-dom';
import { Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

const url = '/admin/traveling/ground_control/buses',
      regUrl = `/admin/traveling/ground_control(?:/buses)?`

const ShowPage = lazy(() => import(/* webpackChunkName: "traveling-ground-control-buses-show-page", webpackPreload: true */ 'pages/traveling/ground-control/buses/show'))
const IndexPage = lazy(() => import(/* webpackChunkName: "traveling-ground-control-buses-index-page", webpackPreload: true */ 'pages/traveling/ground-control/buses/index'))

export default class TravelingGroundControlBusesPage extends Component {

  render() {
    const { location: { pathname } } = this.props

    return (
      <div className="Buses row">
        <div className="col-12 text-center">
          <section className='sub-page-wrapper' id='traveling-pages-wrapper'>
            <header className="container-fluid border-bottom py-3 bg-light">
              <h3 className="row">
                <div className="col-auto">
                  <Link
                    to={`${url}/new`}
                    className={`btn btn-block btn-warning`}
                    disabled={new RegExp(`${regUrl}/new/?$`).test(pathname)}
                  >
                    New Bus
                  </Link>
                </div>
                <div className="col">
                  Buses
                </div>
                <div className="col-auto">
                  <Link
                    to={url}
                    className={`btn btn-block btn-primary`}
                    disabled={new RegExp(`${regUrl}/?$`).test(pathname)}
                  >
                    Back To Index
                  </Link>
                </div>
              </h3>
            </header>
            <div className="main py-5">
              <Suspense fallback={<JellyBox className="page-loader" />}>
                <Switch>
                  <Route
                    path={`${url}/:id`}
                    component={ShowPage}
                  />
                  <Route component={IndexPage} />
                </Switch>
              </Suspense>
            </div>
          </section>
        </div>
      </div>
    );
  }
}
