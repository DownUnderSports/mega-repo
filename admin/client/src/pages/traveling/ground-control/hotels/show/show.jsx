import React                from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
import AsyncComponent       from 'common/js/components/component/async'
import HotelForm            from 'forms/hotel-form'
import HotelRoomsForm        from 'forms/hotel-rooms-form'

const hotelsUrl = "/admin/traveling/ground_control/hotels"

export default class TravelingGroundControlHotelsShowPage extends AsyncComponent {
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
    this.state = { hotel: {}, loading: true }
  }

  componentDidUpdate(prevProps) {
    try {
      const { match: { params: { id } } } = prevProps
      if(!+id && (id !== "new")) throw new Error("Invalid ID")

      if(id !== this.id) this.afterMount()
    } catch(_) {
      this.backToIndex()
    }
  }

  mainKey = () => this.id
  resultKey = () => 'hotel'
  url = (id) => `${hotelsUrl}/${id}.json`
  defaultValue = () => ({ })

  afterMountFetch = ({ hotel = {}, skipTime = false }) => {
    return this.setStateAsync({
      loading: false,
      hotel: hotel || {},
      lastFetch: skipTime ? this.state.lastFetch : +(new Date())
    })
  }

  redirectOrReload = (id) =>
    +id === +(this.id)
      ? this.afterMount()
      : this.props.history.push(`${hotelsUrl}/${id}`)

  backToIndex = () => this.props.history.push(hotelsUrl)

  render() {
    return (
      <DisplayOrLoading display={!this.state.loading}>
        <HotelForm
          hotel={this.state.hotel || {}}
          key={`${this.id}.${this.state.hotel.id}.${this.state.hotel.name}`}
          onCancel={this.backToIndex}
          onSuccess={this.redirectOrReload}
        >
          <HotelRoomsForm
            hotelId={this.state.hotel.id}
            buttonText={this.state.hotel.name}
            key={`${this.id}.${this.state.hotel.id}.${this.state.hotel.name}.travelers`}
          />
        </HotelForm>
      </DisplayOrLoading>
    );
  }
}
