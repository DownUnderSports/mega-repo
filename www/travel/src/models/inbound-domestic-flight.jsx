import BaseModel from 'models/base'

class InboundDomesticFlightModel extends BaseModel {
  modelName = 'inbound_domestic_flights'
  storeName = 'inboundDomesticFlights'
}

export default new InboundDomesticFlightModel()
