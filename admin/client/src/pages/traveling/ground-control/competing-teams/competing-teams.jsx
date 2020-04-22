import React, { Component, Suspense, lazy } from 'react';
import { Route, Switch } from 'react-router-dom';
import { Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

const url = '/admin/traveling/ground_control/competing_teams'

const ShowPage = lazy(() => import(/* webpackChunkName: "traveling-ground-control-competing-teams-show-page", webpackPreload: true */ 'pages/traveling/ground-control/competing-teams/show'))
const IndexPage = lazy(() => import(/* webpackChunkName: "traveling-ground-control-competing-teams-index-page", webpackPreload: true */ 'pages/traveling/ground-control/competing-teams/index'))

export default class TravelingGroundControlCompetingTeamsPage extends Component {

  render() {
    const { location: { pathname } } = this.props

    return (
      <div className="CompetingTeams row">
        <div className="col-12 text-center">
          <section className='sub-page-wrapper' id='traveling-pages-wrapper'>
            <header className="container-fluid border-bottom py-3 bg-light">
              <h3 className="row">
                <div className="col-auto">
                  <Link
                    to={`${url}/new`}
                    className={`btn btn-block btn-warning`}
                    disabled={new RegExp(`${url}/new/?$`).test(pathname)}
                  >
                    New Competing Team
                  </Link>
                </div>
                <div className="col">
                  CompetingTeams
                </div>
                <div className="col-auto">
                  <Link
                    to={url}
                    className={`btn btn-block btn-primary`}
                    disabled={new RegExp(`${url}/?$`).test(pathname)}
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
