import React, { Component, Suspense, lazy } from 'react'
import { Route, Switch } from 'react-router-dom';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { Sport } from 'common/js/contexts/sport';

const invalidSport = ((props) => <div className="list-group-item">Nothing to Do { setTimeout(props.onSuccess, 2000) && false } </div>)

const Sports = {
  BBB: lazy(() => import(/* webpackChunkName: "event-registration-bbb", webpackPrefetch: true */ 'common/js/forms/event-registration-form/components/bbb')),
  CH: invalidSport,
  FB: lazy(() => import(/* webpackChunkName: "event-registration-fb", webpackPrefetch: true */ 'common/js/forms/event-registration-form/components/fb')),
  GBB: lazy(() => import(/* webpackChunkName: "event-registration-gbb", webpackPrefetch: true */ 'common/js/forms/event-registration-form/components/gbb')),
  GF: lazy(() => import(/* webpackChunkName: "event-registration-gf", webpackPrefetch: true */ 'common/js/forms/event-registration-form/components/gf')),
  TF: lazy(() => import(/* webpackChunkName: "event-registration-tf", webpackPrefetch: true */ 'common/js/forms/event-registration-form/components/tf')),
  VB: lazy(() => import(/* webpackChunkName: "event-registration-vb", webpackPrefetch: true */ 'common/js/forms/event-registration-form/components/vb')),
  XC: invalidSport,
}

export default class EventRegistrationForm extends Component {
  static contextType = Sport.Context

  get sportState() {
    return (this.context || {}).sportState || {}
  }

  get sportMappings() {
    return this.sportState.mappings || {}
  }

  get sports() {
    return this.sportState.sports || {}
  }

  get gender() {
    return (this.props || {}).gender
  }

  constructor(props) {
    super(props)
    this.state = {}
  }

  async componentDidMount() {
    await this.context.sportActions.getSports()
    this.setSportTitle()
  }

  onChange = (k, v) => {
    console.log(k, v)
    this.setState({[k]: v, [`${k}_validated`]: 'was-validated'}, () => (k === 'sport_id') && this.setSportTitle())
  }

  setSportTitle = () => this.props.setSportTitle((this.sports[this.sportMappings[this.state.sport_id || (this.props.sport || {}).id]] || {}).fullGender)

  getSportComponent = (k) => {
    const SportComponent = Sports[(this.sports[this.sportMappings[k]] || {}).abbrGender]
    return () => <SportComponent parent={this} onSuccess={this.props.onSuccess} />
  }

  render() {
    return (
      this.sportState.loaded
      && (
        <Suspense fallback={<JellyBox className="page-loader" />}>
          <Switch>
            {
              Object.keys(this.sportMappings).map(
                (k) =>
                  <Route key={k} path={`${this.props.path}/${k}`} render={this.getSportComponent(k)} />
              )
            }
            <Route key='root' render={this.getSportComponent((this.props.sport || {}).id)} />
          </Switch>
        </Suspense>
      )
    )
  }
}
