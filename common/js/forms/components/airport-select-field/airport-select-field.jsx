import React, { Component } from 'react';
import { TextField, SelectField } from 'react-component-templates/form-components';
import airportCities from 'common/assets/json/airports'
import "./airport-select-field.css"

const airportOptions = []
for(let code in airportCities) {
  const values = airportCities[code]
  airportOptions.push({
    id: code,
    value: code,
    code,
    label: `${code}: ${values[0].replace(/[A-Z]+$/, values[1])}`
  })
}

export default class AirportSelectField extends Component {
  constructor(props) {
    super(props)
    this.state = { custom: !!props.value && !airportCities[props.value] }
  }

  componentDidUpdate(props) {
    if(props.value !== this.props.value) {
      this.props.value && this.setState({ custom: !airportCities[this.props.value] })
    }
  }

  _toggleCustom = () => this.setState({ custom: !this.state.custom })

  render() {
    const { custom } = this.state,
          { viewProps, valueKey, placeholder, label, ...props } = this.props

    console.log(props)

    return (
      <>
        { !!label && <label htmlFor={props.id || props.name.replace(/\./g, '_')}>{ label }</label> }
        <div key="input-group" className="input-group with-template">
          <div className="input-group-prepend">
            <span className="input-group-text" onClick={this._toggleCustom}>
              <i className="material-icons">
                { custom ? 'warning' : 'playlist_add_check' }
              </i>
            </span>
          </div>
          {
            custom
              ? (
                <TextField
                  {...props}
                  placeholder={placeholder || '(MYR)'}
                  skipExtras
                />
              )
              : (
                <SelectField
                  {...props}
                  viewProps={viewProps}
                  valueKey={valueKey}
                  options={airportOptions}
                  filterOptions={{
                    indexes: ['label'],
                    hotSwap: {
                      indexes: ['code'],
                      length: 3
                    }
                  }}
                  skipExtras
                />
              )
          }
        </div>
      </>
    )
  }
}
