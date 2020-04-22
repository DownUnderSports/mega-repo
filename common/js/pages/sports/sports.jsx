import React, { Component } from 'react';
import { Route, Switch } from 'react-router-dom';
import { DisplayOrLoading } from 'react-component-templates/components';

import { Sport } from 'common/js/contexts/sport'

import { Link } from 'react-component-templates/components'

import Index from './index'
import Show from './show'


class SportsPage extends Component {
  /**
   * @type {object}
   * @property {object} sportState - redux state for sports
   * @property {object} sportActions - redux actions for sports
   */
  static propTypes = {
    ...Sport.PropTypes
  }

  constructor(props){
    super(props)
    this.state = {}
  }

  /**
   * Fetch Sports On Mount
   *
   * @private
   */
  async componentDidMount(){
    try {
      const navEl = window.document.getElementById('sport-page-nav-trigger')
      navEl && (navEl.checked = false)
      return await this.props.sportState.loaded ? Promise.resolve() : this.props.sportActions.getSports()
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
    const { match: { path }, location: { pathname }, sportState: { loaded = false, sports = {}, ids: sportIds = [] } } = this.props

    return (
      <DisplayOrLoading display={!!loaded}>
        <section className='sports-wrapper' id='sports-wrapper'>
          <header className=''>
            <nav className="nav sports-nav nav-tabs justify-content-end">
              <input type="checkbox" id="sport-page-nav-trigger" className="nav-trigger sport-page-nav-trigger" />
              <label htmlFor="sport-page-nav-trigger" className="nav-trigger nav-item nav-link d-md-none">
                <span><span></span></span>
                Sports List
              </label>
              {
                sportIds.map((id) => {
                  const sport = sports[id] || {},
                        hasMatch = new RegExp(`/(${id}|${sport.abbrGender})$`, 'i');
                  return (
                    !/CH|ST|SR/.test(sport.abbr) && <Link key={id} to={`${path}/${id}`} className={`nav-item nav-link ${hasMatch.test(pathname) ? 'active' : ''}`}>
                      { sport.fullGender }
                    </Link>
                  )
                })
              }
            </nav>
          </header>
          <div className="row">
            <div className="col mb-3">
              <Link
                className="btn btn-block btn-info"
                to="/open-tryouts"
              >
                Try Out for the Team!
              </Link>
            </div>
          </div>
          <div className="main">
            <Switch>
              <Route path={`${path}/:sportId`} component={Show} />
              <Route component={Index} />
            </Switch>
          </div>
        </section>
      </DisplayOrLoading>
    )
  }
}

export default Sport.Decorator(SportsPage)
