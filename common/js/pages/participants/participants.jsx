import React, { Component } from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
import { Participant } from 'common/js/contexts/participant'
import { Sport } from 'common/js/contexts/sport'
import { States } from 'common/js/contexts/states'
import StateMap from 'common/js/components/state-map'
import SortableTable from 'common/js/components/sortable-table'
import StateSelectField from 'common/js/forms/components/state-select-field'
import pixelTracker from 'common/js/helpers/pixel-tracker'

import './participants.css'

class ParticipantsPage extends Component {
  state = { selected: {abbr: 'all'} }
  stateSelectProps = {
    className: 'form-control',
    autoComplete: 'off',
    required: false,
  }

  async componentDidMount(){
    try {
      pixelTracker('track', 'PageView')
      const sportLoader = this.props.sportState.loaded ? Promise.resolve() : this.props.sportActions.getSports()
      const statesLoader = this.props.statesState.loaded ? Promise.resolve() : this.props.statesActions.getStates()
      const participantLoader = this.props.participantActions.getParticipants()
      return await sportLoader.then(statesLoader).then(participantLoader)
    } catch (e) {
      console.error(e)
    }
  }

  onStateClick = (e) => {
    let target
    if(e.target.tagName === "path"){
      target = e.target.closest("g")
    } else if(e.target.tagName === "g"){
      target = e.target
    }
    this.getParticipants((target || {}).id)
  }

  onStateSelect = (e, v) => {
    if(!this.state.selected || (this.state.selected.abbr !== v.abbr)) this.getParticipants(v.abbr)
  }

  getParticipants = async (selected) => {
    selected = this.props.statesActions.find(selected) || {abbr: 'all'}
    this.setState({ selected })
    this.props.participantActions.getParticipants(selected.abbr)
  }

  render() {
    const { participantState = {}, sportState = {}, statesState = {} } = this.props

    return (
      <div className='participants-page bg-white row'>
        <div className="col">
          <div className="row mb-3">
            <div className="col p-3 text-center bg-inverse">
              <h2 className="text-white">View Past Participants</h2>
            </div>
          </div>
          <div className="row text-muted">
            <div className="col text-center">
              <h3>
                (Scroll Down To View List)
              </h3>
            </div>
          </div>
          <div className="row justify-content-center">
            <StateMap
              onClick={this.onStateClick}
              selected={this.state.selected.abbr}
              className='col'
            />
          </div>
          <div className="row" ref={(tableRow)=>this.tableRow = tableRow}>
            <div className="col">
              <DisplayOrLoading display={(!!sportState.loaded) && (!!statesState.loaded) && (!!participantState.loaded)}>
                <SortableTable
                  headers={['name', 'state', 'school']}
                  data={participantState[this.state.selected.abbr] || []}
                >
                  <StateSelectField
                    viewProps={this.stateSelectProps}
                    onChange={this.onStateSelect}
                    name='p_p_state_select'
                    value={this.state.selected.id}
                    label='Select State'
                    feedback='Select a state from the dropdown, or click any state from the map above to view participants from that state.'
                  />
                </SortableTable>
              </DisplayOrLoading>
            </div>
          </div>
        </div>
      </div>
    );
  }
}

export default Participant.Decorator(Sport.Decorator(States.Decorator(ParticipantsPage)))
