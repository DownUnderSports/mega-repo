import React from 'react'
import BaseModelComponent from 'models/components/base'
import OutboundInternationalFlightModel from 'models/outbound-international-flight'

export default class OutboundInternationalFlightModelComponent extends BaseModelComponent {
  model = OutboundInternationalFlightModel

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
            Name
          </th>
        </tr>
      </thead>
      <tbody>
        {
          (this.state.data || []).map((flight, i) => {
            return (
              <tr key={`${i}.${flight.date}.${flight.code}`}>
                <td>
                  { flight.date }
                </td>
                <td>
                  { flight.code }
                </td>
                <td>
                  { flight.fullName }
                </td>
              </tr>
            )
          })
        }
      </tbody>
    </table>
}
