import React from 'react'
import SportFieldsComponent from './sport-fields-component'
import FBMeasurements from './measurements/fb'

export default class FBFields extends SportFieldsComponent {
  sportAbbr = () => 'FB'
  hasNumbers = () => true

  renderSizeOptions(jersey = false){
    return jersey ? this.sizeOptions("Jersey Sizes") : this.sizeOptions("Shorts Sizes", true)
  }

  sizeOptions(label, shorts = false) {
    return (<optgroup label={label}>
      {
        shorts && <option value='S'>S</option>
      }
      <option value='M'>M</option>
      <option value='L'>L</option>
      {
        new Array(4).fill().map((v, i) => <option key={i} value={(i ? i+1 : '') + 'XL'}>{(i ? i+1 : '')}XL</option>)
      }
    </optgroup>)
  }

  renderSizing() {
    return <FBMeasurements />
  }
}
