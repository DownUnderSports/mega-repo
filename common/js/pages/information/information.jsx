import React, { Component } from 'react';

import { Sport } from 'common/js/contexts/sport'
import { States } from 'common/js/contexts/states'

import { DisplayOrLoading } from 'react-component-templates/components';

import InfokitForm from 'common/js/forms/infokit-form'
import DemoVideo from 'common/js/components/demo-video'
import dusIdFormat from 'common/js/helpers/dus-id-format';
import pixelTracker from 'common/js/helpers/pixel-tracker'

import './information.css'

class InformationPage extends Component {
  async componentDidMount(){
    try {
      const { match: { params: { dusId = '' } } } = this.props
      if(dusId && (dusId !== dusIdFormat(dusId))) {
        return this.props.history.push(`/${dusIdFormat(dusId)}`)
      }
      pixelTracker('track', 'PageView')
      const sportLoader = this.props.sportState.loaded ? Promise.resolve() : this.props.sportActions.getSports()
      const statesLoader = this.props.statesState.loaded ? Promise.resolve() : this.props.statesActions.getStates()
      return await sportLoader.then(statesLoader)
    } catch (e) {
      console.error(e)
    }
  }

  render() {
    const { sportState = {}, statesState = {}, match: { params: { dusId = '' } } } = this.props

    return (
        <div className="infokit-page">
          <div className="row form-group">
            <div className="col">
              <DisplayOrLoading display={(!!sportState.loaded) && (!!statesState.loaded)}>
                <InfokitForm dusId={dusId} />
              </DisplayOrLoading>
            </div>
          </div>
          <div className="row my-5">
            <div className="col">
              <DemoVideo />
            </div>
          </div>
        </div>
    );
  }
}

export default Sport.Decorator(States.Decorator(InformationPage))
