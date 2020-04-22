import React from 'react'
import SportFieldsComponent from './sport-fields-component'
import GBBAndBBBMeasurements from './measurements/bbb-and-gbb'

export default class BBBAndGBBFields extends SportFieldsComponent {
  renderSizeOptions(jersey = false) {
    return jersey ? this.sizeOptions("Jersey Sizes", 2) : this.sizeOptions("Shorts Sizes", 2)
  }

  sizeOptions(label) {
    return (<optgroup label={label}>
      <option value='S'>S</option>
      <option value='M'>M</option>
      <option value='L'>L</option>
      <option value='XL'>XL</option>
      <option value='2XL'>2XL</option>
    </optgroup>)
  }

  renderSizing() {
    return <GBBAndBBBMeasurements />
  }
}
