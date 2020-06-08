import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import AirportForm from 'forms/airport-form'

const airportsUrl = "/admin/traveling/flights/airports"

export default class TravelingFlightsAirportsShowPage extends AsyncComponent {
  get id(){
    try {
      const { match: { params: { id } } } = this.props
      return id
    } catch(_) {
      return 'new'
    }
  }

  constructor(props) {
    super(props)
    this.state = { airport: {}, loading: true }
  }

  mainKey = () => this.id
  resultKey = () => 'airport'
  url = (id) => `${airportsUrl}/${id}.json`
  defaultValue = () => ({})

  afterFetch = ({airport, skipTime = false}) => this.setStateAsync({
    loading: false,
    airport: airport || {},
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  backToIndex = () => this.props.history.push(airportsUrl)

  render() {
    return (
      <AirportForm
        airport={this.state.airport || {}}
        key={`${this.id}.${this.state.airport.id}.${this.state.airport.code}`}
        onCancel={this.backToIndex}
        onSuccess={this.backToIndex}
      />
    );
  }
}
