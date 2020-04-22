import React, { Component, Suspense } from 'react'
import { BrowserRouter as Router, Route, Switch } from 'react-router-dom';
import checkVersion from 'common/js/helpers/check-version'
import Admin from 'layouts/admin';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import routes from 'routes'
import QueueTracker from 'components/queue-tracker'
import { MenuRedux } from 'react-component-templates/contexts';

import HotelRedux from 'common/js/contexts/hotel';
import InterestRedux from 'common/js/contexts/interest';
import MeetingRedux from 'common/js/contexts/meeting';
import NationalityRedux from 'common/js/contexts/nationality';
import SportRedux from 'common/js/contexts/sport';
import StatesRedux from 'common/js/contexts/states';
import StaffUsersRedux from 'common/js/contexts/staff-users';
import VideoRedux from 'common/js/contexts/video';
// import UserRedux from 'common/js/contexts/user';
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

export default class AdminRouter extends Component {
  async componentDidMount(){
    await checkVersion()
  }

  render () {
    return (
      <HotelRedux>
        <NationalityRedux>
          <StatesRedux>
            <SportRedux>
              <VideoRedux>
                <MeetingRedux>
                  <StaffUsersRedux>
                    <InterestRedux>
                      <MenuRedux>
                        <Router>
                          <Admin>
                            <Suspense fallback={<JellyBox className="page-loader" />}>
                              <Switch>
                                {
                                  routes.map((route, i) => <Route key={i} {...route}/>)
                                }
                              </Switch>
                            </Suspense>
                          </Admin>
                        </Router>
                        <QueueTracker />
                      </MenuRedux>
                    </InterestRedux>
                  </StaffUsersRedux>
                </MeetingRedux>
              </VideoRedux>
            </SportRedux>
          </StatesRedux>
        </NationalityRedux>
      </HotelRedux>
    )
  }
}
