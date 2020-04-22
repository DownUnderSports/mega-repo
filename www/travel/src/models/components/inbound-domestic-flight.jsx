import React from 'react'
import BaseModelComponent from 'models/components/base'
import InboundDomesticFlightModel from 'models/inbound-domestic-flight'

export default class InboundDomesticFlightModelComponent extends BaseModelComponent {
  model = InboundDomesticFlightModel
  keyPath = [ 'code', 'date' ]
  
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
