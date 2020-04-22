import BaseModel from 'models/base'

class FlightScheduleModel extends BaseModel {
  modelName = 'flight_schedules'
  storeName = 'flightSchedules'
}

export default new FlightScheduleModel()
