import React, {createContext, Component} from 'react'
import { objectOf, arrayOf, func, shape, string, number, bool } from 'prop-types'
//import authFetch from 'common/js/helpers/auth-fetch'
import { Spaceship }  from 'react-component-templates/helpers'

const hotelUrl = '/admin/traveling/ground_control/hotels.json'

export const Hotel = {}

Hotel.hydrationParamsKey = 'hotelsListContext'

Hotel.DefaultValues = {
  ids: [],
  loaded: false,
  mappings: {},
  hotels: {},
}

Hotel.Context = createContext({
  hotelState: {...Hotel.DefaultValues},
  hotelActions: {
    getHotels(){},
    find(){},
  }
})

Hotel.Decorator = function withHotelContext(Component) {
  return (props) => (
    <Hotel.Context.Consumer>
      {hotelProps => <Component {...props} {...hotelProps} />}
    </Hotel.Context.Consumer>
  )
}

Hotel.hotelShape = () => shape({
  id: number.isRequired,
  area: string.isRequired,
  city: string.isRequired,
  country: string.isRequired,
  name: string.isRequired,
  phone: string,
})

Hotel.PropTypes = {
  hotelState: shape({
    ids: arrayOf(number),
    loaded: bool,
    mappings: objectOf(number),
    hotels: objectOf(
      Hotel.hotelShape()
    ),
  }),
  hotelActions: shape({
    getHotels: func,
    find: func,
  }).isRequired
}

const mapHotelProps = (hotel, show = false) => ({
  id: +hotel.id,
  area: hotel.area,
  city: hotel.city,
  country: hotel.country,
  name: hotel.name,
  phone: hotel.phone,
})

export default class ReduxHotelProvider extends Component {
  state = window.ssrHydrationParams[Hotel.hydrationParamsKey] || { ...Hotel.DefaultValues }

  componentDidUpdate() {
    if(window.shouldMakeHydrationParamsPublic) {
      window.ssrHydrationParams[Hotel.hydrationParamsKey] = this.state
    }
  }

  render() {
    return (
      <Hotel.Context.Provider
        value={{
          hotelState: this.state,
          hotelActions: {
            /**
             * @returns {object} retrieved - id mapped object of states
             **/
            getHotels: async () => {
              try {
                const result = await fetch(hotelUrl),
                      retrieved = await result.json(),
                      hotels = {},
                      mappings = {}

                const ids = (retrieved.hotels || []).map((hotel) => {
                  hotel = mapHotelProps(hotel)
                  hotels[hotel.id] = hotel
                  mappings[hotel.id] = hotel.id
                  mappings[hotel.name] = hotel.id
                  return hotel.id
                }).sort((a, b) => Spaceship.operator(hotels[a], hotels[b], ['name', 'country', 'area', 'city']))

                this.setState({
                  ids,
                  hotels,
                  mappings,
                  loaded: true
                })

                return {...hotels}

              } catch (e) {
                this.setState({
                  hotels: {},
                  loaded: true
                })

                return {}
              }
            },
            find: (val) => this.state.hotels[this.state.mappings[val]]
          }
        }}
      >
        {this.props.children}
      </Hotel.Context.Provider>
    )
  }
}
