import React, { Component, Suspense, lazy } from 'react'
import { Route, Switch } from 'react-router-dom';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { Sport } from 'common/js/contexts/sport';

const Sports = {
  BBB: lazy(() => import(/* webpackChunkName: "uniform-order-bbb", webpackPrefetch: true */ 'common/js/forms/uniform-order-form/components/bbb')),
  CH: () => <div>N/A</div>,
  FB: lazy(() => import(/* webpackChunkName: "uniform-order-fb", webpackPrefetch: true */ 'common/js/forms/uniform-order-form/components/fb')),
  GBB: lazy(() => import(/* webpackChunkName: "uniform-order-gbb", webpackPrefetch: true */ 'common/js/forms/uniform-order-form/components/gbb')),
  GF: lazy(() => import(/* webpackChunkName: "uniform-order-gf", webpackPrefetch: true */ 'common/js/forms/uniform-order-form/components/gf')),
  TF: lazy(() => import(/* webpackChunkName: "uniform-order-tf", webpackPrefetch: true */ 'common/js/forms/uniform-order-form/components/tf')),
  VB: lazy(() => import(/* webpackChunkName: "uniform-order-vb", webpackPrefetch: true */ 'common/js/forms/uniform-order-form/components/vb')),
  XC: lazy(() => import(/* webpackChunkName: "uniform-order-xc", webpackPrefetch: true */ 'common/js/forms/uniform-order-form/components/xc')),
}

export default class UniformOrderForm extends Component {
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
    return () => <SportComponent parent={this} />
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
