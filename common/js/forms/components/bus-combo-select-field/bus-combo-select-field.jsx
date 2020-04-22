import React, { Component } from 'react';
import { SelectField } from 'react-component-templates/form-components';
import busCombos from 'common/assets/json/bus-combos'

const comboOptions = []
for(let name in busCombos) {
  const combo = busCombos[name]
  comboOptions.push({
    id: name,
    value: name,
    ...combo,
    label: `${name} (${combo.color})`
  })
}

export default class BusComboSelectField extends Component {
  render() {
    return (
      <SelectField
        {...this.props}
        options={comboOptions}
        filterOptions={{
          indexes: ['label'],
        }}
      />
    )
  }
}
