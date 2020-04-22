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
                Bust/Chest:
              </th>
              <td>
                With arms relaxed at sides measure around the body at the fullest part of the bust/chest, keeping the tape parallel to floor.
              </td>
            </tr>
            <tr>
              <th>
                Waist:
              </th>
              <td>
                Measure around the body (not on top of clothing) at the waist level.
              </td>
            </tr>
            <tr>
              <th>
                Hip:
              </th>
              <td>
                With feet together, measure around the fullest part at the hip level, keeping the tape parallel to the floor.
              </td>
            </tr>
            <tr>
              <th>
                Inseam:
              </th>
              <td>
                With feet slightly apart, measure vertically from the top inside of the leg down to the ankle bone.
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    )
  }
}
