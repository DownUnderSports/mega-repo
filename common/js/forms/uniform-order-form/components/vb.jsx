import React from 'react'
import SportFieldsComponent from './sport-fields-component'
import VBMeasurements from './measurements/vb'

export default class VBFields extends SportFieldsComponent {
  sportAbbr = () => 'VB'

  renderSizeOptions(jersey = false) {
    return jersey ? this.sizeOptions("Jersey Sizes") : this.sizeOptions("Shorts Sizes")
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
    return <VBMeasurements />
  }
}
