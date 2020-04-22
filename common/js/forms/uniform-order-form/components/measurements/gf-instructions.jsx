import React, { PureComponent } from 'react'

export default class BadgerMeasurements extends PureComponent {
  render() {
    return (
      <section className="card">
        <header className="card-header">
          <h4>How To Measure:</h4>
        </header>
        <table className="table">
          <tbody>
            <tr>
              <th>
                Chest:
              </th>
              <td>
                Measured across the chest one inch below armhole when laid flat.
              </td>
            </tr>
            <tr>
              <th>
                Sleeve Length:
              </th>
              <td>
                Start at center of neck and measure down shoulder, down sleeve to hem.
              </td>
            </tr>
            <tr>
              <th>
                Body Length At Back:
              </th>
              <td>
                Measured from high point shoulder to finished hem at back.
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    )
  }
}
