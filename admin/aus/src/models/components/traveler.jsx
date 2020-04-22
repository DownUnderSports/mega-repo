import React from 'react'
import BaseModelComponent from 'models/components/base'
import TravelerModel from 'models/traveler'

export default class TravelerModelComponent extends BaseModelComponent {
  model = TravelerModel

  displayTable = () =>
    <table className="table">
      <thead>
        <tr>
          <th>
            User ID
          </th>
          <th>
            Balance
          </th>
        </tr>
      </thead>
      <tbody>
        {
          (this.state.data || []).map((traveler, i) => {
            return (
              <tr key={`${traveler.id}.${i}`}>
                <td>
                  { traveler.userId }
                </td>
                <td>
                  { traveler.balance && traveler.balance.str_pretty }
                </td>
              </tr>
            )
          })
        }
      </tbody>
    </table>
}
