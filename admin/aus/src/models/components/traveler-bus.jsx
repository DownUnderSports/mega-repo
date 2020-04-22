import React from 'react'
import BaseModelComponent from 'models/components/base'
import TravelerBusModel from 'models/traveler-bus'

export default class TravelerBusModelComponent extends BaseModelComponent {
  model = TravelerBusModel

  displayTable = () =>
    <table className="table">
      <thead>
        <tr>
          <th>
            User ID
          </th>
          <th>
            DUS ID
          </th>
          <th>
            First Name(s)
          </th>
          <th>
            Last Name(s)
          </th>
        </tr>
      </thead>
      <tbody>
        {
          (this.state.data || []).map((user, i) => {
            return (
              <tr key={`${user.id}.${i}`}>
                <td>
                  { user.id }
                </td>
                <td>
                  { user.dusId }
                </td>
                <td>
                  { user.printFirstNames || user.first }
                </td>
                <td>
                  { user.printLastNames || user.last }
                </td>
              </tr>
            )
          })
        }
      </tbody>
    </table>
}
