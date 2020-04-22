import React from 'react'
import SportFieldsComponent from './sport-fields-component'
import TFAndXCMeasurements from './measurements/tf-and-xc'

export default class TFAndXCFields extends SportFieldsComponent {
  renderSizeOptions(jersey = false) {
    return [
      ...(this.parentForm.gender === 'F' ? [this.sizeOptions("Women's Sizes", 2, 'W-')] : []),
      this.sizeOptions("Men's/Unisex Sizes", 5, 'M-')
    ]
  }

  sizeOptions(label = "Men's/Unisex Sizes", max = 2, valuePrefix = ''){
    return (<optgroup key={Date.now() + "" + Math.random() } label={label}>
      <option value={`${valuePrefix}XS`}>{valuePrefix}XS</option>
      <option value={`${valuePrefix}S`}>{valuePrefix}S</option>
      <option value={`${valuePrefix}M`}>{valuePrefix}M</option>
      <option value={`${valuePrefix}L`}>{valuePrefix}L</option>
      {
        new Array(max).fill('').map((v, i) => <option key={i} value={`${valuePrefix}${(i ? i+1 : '')}XL`}>{valuePrefix}{(i ? i+1 : '')}XL</option>)
      }
    </optgroup>)
  }

  renderSizing(showWomen) {
    return <TFAndXCMeasurements showWomen={showWomen} />
  }
}
