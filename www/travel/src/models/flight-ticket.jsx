import BaseModel from 'models/base'

class FlightTicketModel extends BaseModel {
  modelName = 'flight_Tickets'
  storeName = 'flightTickets'
}

export default new FlightTicketModel()
