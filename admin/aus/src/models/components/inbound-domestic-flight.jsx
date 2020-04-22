import React from 'react'
import BaseModelComponent from 'models/components/base'
import InboundDomesticFlightModel from 'models/inbound-domestic-flight'
import throttle from 'helpers/throttle'

export default class InboundDomesticFlightModelComponent extends BaseModelComponent {
  model = InboundDomesticFlightModel
  keyPath = [ 'code', 'date' ]

  streamUpdater = throttle(() => {
    if(!this._isMounted) return false

    this.setState({
      loadingRecords: `Loading in Background: ${ (this.liveData || []).length } Airport(s)/Dates (~65 Total)`
    })
  })

  displayTable = () =>
    <table className="table">
      <thead>
        <tr>
          <th>
            Date
          </th>
          <th>
            Intl Airport Code
          </th>
          <th>
            Total Flights
          </th>
        </tr>
      </thead>
      <tbody>
        {
          (this.state.data || []).map((ibdFlight, i) => {
            return (
              <tr key={`${i}.${ibdFlight.date}.${ibdFlight.code}`}>
                <td>
                  { ibdFlight.date }
                </td>
                <td>
                  { ibdFlight.code }
                </td>
                <td>
                  { (ibdFlight.flights || []).length }
                </td>
              </tr>
            )
          })
        }
      </tbody>
    </table>
}
