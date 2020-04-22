import React, { Component } from 'react';
import { Hotel } from 'common/js/contexts/hotel';
import { Objected } from 'react-component-templates/helpers'
import { SelectField } from 'react-component-templates/form-components';

export default class HotelSelectField extends Component {
  static contextType = Hotel.Context

  constructor(props){
    super(props)
    this.state = {
      options: []
    }
  }

  async componentDidMount(){
    this._isMounted = true
    try {
      return await (this.context.hotelState.loaded ? Promise.resolve() : this.context.hotelActions.getHotels())
      .then(this.mapOptions)
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate(){
    if(!this._isMounted) return false
    const { loaded = false, options = [] } = this.state
    if(
      (!loaded && this.context.hotelState.loaded) ||
      (options.length !== this.context.hotelState.ids.length)
    ) {
      this.mapOptions()
    }
  }

  componentWillUnmount() {
    this._isMounted = false
  }

  mapOptions = () => {
    if(!this._isMounted) return false

    const { hotelState: { ids = [], loaded = false }, hotelActions: {find = ((v) => v)} } = this.context;
    this.setState({
      loaded,
      options: ids.map((id) => find(id)).map((hotel) => ({
        id: hotel.id,
        value: hotel.id,
        label: `${hotel.name} (${hotel.city}, ${hotel.country})`,
      }))
    })
  }

  render() {
    return (
      <SelectField
        {...Objected.filterKeys(this.props, ['hotelState', 'hotelActions'])}
        options={this.state.options}
        filterOptions={{
          indexes: ['name','label'],
        }}
      />
    )
  }
}
