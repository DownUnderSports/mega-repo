import BaseModel from 'models/base'

class FlightTicketModel extends BaseModel {
  modelName = 'flight_tickets'
  storeName = 'flightTickets'
}

export default new FlightTicketModel()
