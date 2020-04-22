import React, { Component } from 'react';
import { SelectField } from 'react-component-templates/form-components';

export const shirtOptions = [
  {
    value: 'A-S',
    label: 'Adult S'
  },
  {
    value: 'A-M',
    label: 'Adult M'
  },
  {
    value: 'A-L',
    label: 'Adult L'
  },
  {
    value: 'A-XL',
    label: 'Adult XL'
  },
  {
    value: 'A-2XL',
    label: 'Adult 2XL'
  },
  {
    value: 'A-3XL',
    label: 'Adult 3XL'
  },
  {
    value: 'A-4XL',
    label: 'Adult 4XL'
  },
  {
    value: 'Y-XS',
    label: 'Youth XS'
  },
  {
    value: 'Y-S',
    label: 'Youth S'
  },
  {
    value: 'Y-M',
    label: 'Youth M'
  },
  {
    value: 'Y-L',
    label: 'Youth L'
  },
]

export default class ShirtSizeSelectField extends Component {
  render() {
    return (
      <SelectField
        {...this.props}
        options={shirtOptions}
        valueKey='value'
      />
    )
  }
}
