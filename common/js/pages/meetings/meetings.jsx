import React, { Component, Suspense, lazy } from 'react';
import { Route, Switch } from 'react-router-dom';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

import { Meeting } from 'common/js/contexts/meeting'

import { Link } from 'react-component-templates/components'

import './meetings.css'

const Index = lazy(() => import(/* webpackChunkName:  "meetings-index-page" */ 'common/js/pages/meetings/index'))
const Show = lazy(() => import(/* webpackChunkName: "meetings-show-page" */ 'common/js/pages/meetings/show'))

class MeetingsPage extends Component {
  /**
   * @type {object}
   * @property {object} meetingState - redux state for meetings
   * @property {object} meetingActions - redux actions for meetings
   */
  static propTypes = {
    ...Meeting.PropTypes
  }

  constructor(props){
    super(props)
    this.state = {}
  }

  /**
   * Fetch Meetings On Mount
   *
   * @private
   */
  async componentDidMount(){
    try {
      return await this.props.meetingState.loaded ? Promise.resolve() : this.props.meetingActions.getMeetings()
    } catch (e) {
      console.error(e)
    }
  }

  async componentDidUpdate(props){
    try {
      const { location: { pathname: oldPathName } } = props,
            { location: { pathname: newPathName }} = this.props
      if(newPathName !== oldPathName) await this.componentDidMount()
    } catch (e) {
      console.error(e)
    }
  }

  render() {
    const { match: { path }, location: { pathname }, meetingState: { loaded = false, meetings = {}, ids: meetingIds = [] } } = this.props

    return (
      <DisplayOrLoading display={!!loaded}>
        <div className="main">
          <Suspense fallback={<JellyBox className="page-loader" />}>
            <Switch>
              <Route path={`${path}/:meetingId`} component={Show} />
              <Route component={Index} />
            </Switch>
          </Suspense>
        </div>
      </DisplayOrLoading>
    )
  }
}

export default Meeting.Decorator(MeetingsPage)
