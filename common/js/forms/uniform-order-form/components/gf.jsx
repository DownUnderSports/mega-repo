import React from 'react'
import SportFieldsComponent from './sport-fields-component'
import GFMeasurements from './measurements/gf'

export default class GFFields extends SportFieldsComponent {
  sportAbbr = () => 'GF'
  shortsRequired = () => false

  formFields = () => (
    <div className="row">
      <div className="col-md col-12 form-group">
        <label htmlFor="uniform_order_jersey_size">
          Polo<span className="text-danger">*</span>
        </label>
        <select
          name="uniform_order[jersey_size]"
          id="uniform_order_jersey_size"
          className="form-control"
          value={this.parentState.jersey_size || ''}
          onChange={this.onJerseyChange}
          required
        >
          <option value="" disabled="disabled">Select Polo Size...</option>
          {this.renderSizeOptions(true)}
        </select>
      </div>
    </div>
  )

  renderSizeOptions(){
    return this.sizeOptions('Polo Sizes', 4)
  }

  renderSizing() {
    return <GFMeasurements />
  }
}
