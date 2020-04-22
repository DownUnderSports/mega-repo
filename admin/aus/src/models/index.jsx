import FlightAirport from 'models/flight-airport'
import FlightLeg from 'models/flight-leg'
import FlightSchedule from 'models/flight-schedule'
import FlightTicket from 'models/flight-ticket'
import InboundDomesticFlightModel from 'models/inbound-domestic-flight'
import TravelerModel from 'models/traveler'
import UserModel from 'models/user'

const models = {
  [FlightAirport.modelName]:              FlightAirport,
  [FlightLeg.modelName]:                  FlightLeg,
  [FlightSchedule.modelName]:             FlightSchedule,
  [FlightTicket.modelName]:               FlightTicket,
  [InboundDomesticFlightModel.modelName]: InboundDomesticFlightModel,
  [TravelerModel.modelName]:              TravelerModel,
  [UserModel.modelName]:                  UserModel,
}

export default models
