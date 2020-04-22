import BaseModel from 'models/base'

class FlightAirportModel extends BaseModel {
  modelName = 'flight_airports'
  storeName = 'flightAirports'
}

export default new FlightAirportModel()
