import React, { Component } from 'react'
import PropTypes from 'prop-types'
import { InlineRadioField, TextField } from 'react-component-templates/form-components';
import { CardSection } from 'react-component-templates/components';
import StateSelectField from 'common/js/forms/components/state-select-field'
import CountrySelectField from 'common/js/forms/components/country-select-field'
import { States } from 'common/js/contexts/states';
import zipCodes from 'common/assets/json/zip-codes'

export default class AddressSection extends Component {
  /**
   * @type {object}
   * @property {String|Element} label - Input Label
   * @property {String} name - Input Name
   * @property {String} valuePrefix - state key prefix of onChange
   * @property {Function} onChange - Run on input change
   * @property {object} contentProps - Passthrough props for main
   * @property {object} headerProps - Passthrough props for header
   * @property {object} values - section input values
   */
  static propTypes = {
    label: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.node
    ]),
    name: PropTypes.string.isRequired,
    valuePrefix: PropTypes.string,
    onChange: PropTypes.func,
    contentProps: PropTypes.object,
    headerProps: PropTypes.object,
    values: PropTypes.object,
    required: PropTypes.bool
  }

  static contextType = States.Context

  constructor(props) {
    if(props.validator instanceof RegExp) {
      const validator = props.validator
      props.pattern = validator
      delete props.validator
    }
    super(props)
  }

  async componentDidMount(){
    try {
      return await (this.context.statesState.loaded ? Promise.resolve() : this.context.statesActions.getStates())
    } catch (e) {
      console.error(e)
    }
  }

  onChange(ev) {
    if(this.props.onChange) this.props.onChange(ev)
    if(this.props.validator) ev.target.setCustomValidity(this.props.validator(ev))
  }

  getChangeFunction = (type, valuePrefix, func) => {
    return this[`on${valuePrefix}${type}Change`] || (this[`on${valuePrefix}${type}Change`] = func)
  }

  isBadZip = (code, state_id) => {
    const codes = zipCodes[code],
          states = (!!codes && ((this.context || {}).statesState || {}).states) || {},
          state = states[state_id] || {}
    if(state && codes) {
      return (codes.indexOf(state.abbr) === -1)
    } else {
      return false
    }
  }

  render(){
    const {
            name = '', delegatedChange = () => {}, onChange = delegatedChange, values = {},
            valuePrefix = name,
            id = valuePrefix.replace(/\./g, '_'),
            category = 'shipping',
            inline = false,
            decorateRequired = !!this.props.required,
            required = false,
            ...props
          } = this.props

    let badState = false
    if(!values.is_foreign && !!values.state_id && !!values.zip) {
      let zip = `${values.zip}`.split('-')[0]
      badState = this.isBadZip(zip[0], values.state_id)
      if(badState && (zip.length === 4)) badState = this.isBadZip("0", values.state_id)
    }

    return (
      <CardSection {...props}>
        <div className={`form-group ${values.is_foreign_validated && 'was-validated'}`}>
          <InlineRadioField
            label={`Address Type${decorateRequired ? '*' : ''}`}
            name={`${name}[is_foreign]`}
            options={[
              {value: false, label: 'US Address'},
              {value: true, label: 'Foreign Address'},
            ]}
            value={!!values.is_foreign}
            onChange={this.getChangeFunction('Foreign', valuePrefix, (value) => onChange(false, `${valuePrefix}.is_foreign`, !!value))}
          />
        </div>
        <div className={`form-group ${values.street_validated && 'was-validated'}`}>
          <TextField
            label={`Street${decorateRequired ? '*' : ''}`}
            id={`${id}_street`}
            name={`${name}[street]`}
            type="text"
            className="form-control"
            value={values.street}
            onChange={this.getChangeFunction('Street', valuePrefix, (ev) => onChange(false, `${valuePrefix}.street`, ev.target.value))}
            autoComplete={`${category} address-line1`}
            required={!!required}
          />
        </div>
        <div className={`form-group ${values.street_2_validated && 'was-validated'}`}>
          <TextField
            label='Street 2'
            id={`${id}_street_2`}
            name={`${name}[street_2]`}
            type="text"
            className="form-control"
            value={values.street_2}
            onChange={this.getChangeFunction('StreetTwo', valuePrefix, (ev) => onChange(false, `${valuePrefix}.street_2`, ev.target.value))}
            autoComplete={`${category} address-line2`}
          />
        </div>
        {
          !!values.is_foreign && (
            <div className={`form-group ${values.street_3_validated && 'was-validated'}`}>
              <TextField
                label='Street 3'
                id={`${id}_street_3`}
                name={`${name}[street_3]`}
                type="text"
                className="form-control"
                value={values.street_3}
                onChange={this.getChangeFunction('StreetThree', valuePrefix, (ev) => onChange(false, `${valuePrefix}.street_3`, ev.target.value))}
                autoComplete={`${category} address-line3`}
              />
            </div>
          )
        }
        <div className="row">
          <div className={`${inline ? 'col-lg' : 'col-12'} form-group ${values.city_validated && 'was-validated'}`}>
            <TextField
              label={!!values.is_foreign ? 'City/Locality' : `City${decorateRequired ? '*' : ''}`}
              id={`${id}_city`}
              name={`${name}[city]`}
              type="text"
              className="form-control"
              value={values.city}
              onChange={this.getChangeFunction('City', valuePrefix, (ev) => onChange(false, `${valuePrefix}.city`, ev.target.value))}
              autoComplete={`${category} address-level2`}
              required={!values.is_foreign && (!!required || !!values.street)}
            />
          </div>
          {
            !!values.is_foreign ? (
              <div className={`${inline ? 'col-lg' : 'col-12'} form-group ${values.province_validated && 'was-validated'}`}>
                <TextField
                  label={`Province/Parish${decorateRequired ? '*' : ''}`}
                  id={`${id}_province`}
                  name={`${name}[province]`}
                  type="text"
                  className="form-control"
                  value={values.province}
                  onChange={this.getChangeFunction('Province', valuePrefix, (ev) => onChange(false, `${valuePrefix}.province`, ev.target.value))}
                  autoComplete={`${category} address-level1`}
                  required={!!required || !!values.street}
                />
              </div>
            ) : (
              <div className={`${inline ? 'col-lg' : 'col-12'} ${inline ? 'col ' : ''}form-group ${values.state_id_validated && 'was-validated'}`}>
                <StateSelectField
                  label={`State${decorateRequired ? '*' : ''}`}
                  id={`${id}_state_id`}
                  name={`${name}[state_id]`}
                  value={values.state_id}
                  onChange={this.getChangeFunction('State', valuePrefix, (ev, option) => onChange(false, `${valuePrefix}.state_id`, (option || {}).value))}
                  viewProps={{
                    className: 'form-control',
                    autoComplete: `${category} address-level1`,
                    required: !!required || !!values.street,
                  }}
                />
              </div>
            )
          }
          <div className={`${inline ? 'col-lg' : 'col-12'} form-group ${values.zip_validated && 'was-validated'}`}>
            <TextField
              label={`Zip Code${decorateRequired ? '*' : ''}`}
              id={`${id}_zip`}
              name={`${name}[zip]`}
              type="text"
              className="form-control"
              value={values.zip}
              onChange={this.getChangeFunction('Zip', valuePrefix, (ev) => onChange(false, `${valuePrefix}.zip`, ev.target.value))}
              autoComplete={`${category} postal-code`}
              inputMode="numeric"
              required={!!required}
            />
          </div>
          {
            !!badState && (
              <div className="col-12 form-group was-validated">
                <span className="invalid-feedback d-block">
                  The selected state appears not to match the provided zip code. Please double check that all information entered is valid and correct.
                </span>
              </div>
            )
          }
        </div>
        {
          !!values.is_foreign && (
            <div className={`form-group ${values.country_validated && 'was-validated'}`}>
              <CountrySelectField
                label={`Country${decorateRequired ? '*' : ''}`}
                id={`${id}_country`}
                name={`${name}[country]`}
                value={values.country}
                onChange={this.getChangeFunction('Country', valuePrefix, (ev, option) => onChange(false, `${valuePrefix}.country`, (option || {}).value))}
                viewProps={{
                  className: 'form-control',
                  autoComplete: `${category} country`,
                  required: !!required || !!values.street,
                }}
              />
            </div>
          )
        }
        { this.props.children }
      </CardSection>
    )
  }
}
