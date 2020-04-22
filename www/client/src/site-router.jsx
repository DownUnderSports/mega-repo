import React, { Component, Suspense } from 'react'
import { BrowserRouter as Router, Route, Switch } from 'react-router-dom';

import checkVersion from 'common/js/helpers/check-version'

import Site from 'common/js/layouts/site';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import LocationChange from 'common/js/components/location-change'

import routes from 'routes'

import { ConnectionSpeedRedux, MenuRedux } from 'react-component-templates/contexts';

import ArticleRedux from 'common/js/contexts/article';
import BackgroundRedux from 'common/js/contexts/background';
import HomeGalleryRedux from 'common/js/contexts/home-gallery';
import MeetingRedux from 'common/js/contexts/meeting';
import NationalityRedux from 'common/js/contexts/nationality';
import ParticipantRedux from 'common/js/contexts/participant';
import SportRedux from 'common/js/contexts/sport';
import StatesRedux from 'common/js/contexts/states';
import PropTypes from 'prop-types';

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

window.clientSite = true

export default class SiteRouter extends Component {
  async componentDidMount(){
    checkVersion()
  }

  render () {
    return (
      <ConnectionSpeedRedux key="ConnectionSpeedRedux">
        <BackgroundRedux key="BackgroundRedux">
          <HomeGalleryRedux key="HomeGalleryRedux">
            <ArticleRedux key="ArticleRedux">
              <ParticipantRedux key="ParticipantRedux">
                <NationalityRedux key="NationalityRedux">
                  <MeetingRedux key="MeetingRedux">
                    <StatesRedux key="StatesRedux">
                      <SportRedux key="SportRedux">
                        <MenuRedux key="MenuRedux">
                          <Router key="SiteRouter">
                            <Route key="LocationChangeTracker" component={LocationChange} />
                            <Site key="MainSite">
                              <Suspense key="SuspenseHelper" fallback={<JellyBox className="page-loader" />}>
                                <Switch key="SiteSwitch">
                                  {
                                    routes.map((route, i) => <Route key={route.path || i} {...route}/>)
                                  }
                                </Switch>
                              </Suspense>
                            </Site>
                          </Router>
                        </MenuRedux>
                      </SportRedux>
                    </StatesRedux>
                  </MeetingRedux>
                </NationalityRedux>
              </ParticipantRedux>
            </ArticleRedux>
          </HomeGalleryRedux>
        </BackgroundRedux>
      </ConnectionSpeedRedux>
    )
  }
}
