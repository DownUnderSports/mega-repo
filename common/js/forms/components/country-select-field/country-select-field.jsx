import React, { Component } from 'react';
import { SelectField } from 'react-component-templates/form-components';
import countries from 'common/assets/json/countries'

const countryOptions = []
for(let code in countries) {
  const country = countries[code]
  countryOptions.push({
    id: code,
    value: code,
    code,
    label: `${code}: ${country.name}`
  })
}

export default class CountrySelectField extends Component {
  render() {
    return (
      <SelectField
        {...this.props}
        options={countryOptions}
        filterOptions={{
          indexes: ['label'],
          hotSwap: {
            indexes: ['code'],
            length: 3
          }
        }}
      />
    )
  }
}
