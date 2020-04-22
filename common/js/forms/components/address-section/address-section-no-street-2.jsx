import React, { Component } from 'react'
import PropTypes from 'prop-types'
import { InlineRadioField, TextField, SelectField } from 'react-component-templates/form-components';
import { CardSection } from 'react-component-templates/components';
import StateSelectField from 'common/js/forms/components/state-select-field'
import CountrySelectField from 'common/js/forms/components/country-select-field'
import { States } from 'common/js/contexts/states';
import zipCodes from 'common/assets/json/zip-codes'

const streetTwoOptions = [
  { value: 'Apt',    label: 'Apartment' },
  { value: 'Ste',    label: 'Suite'     },
  { value: 'PO Box', label: 'PO Box'    },
  { value: 'ATTN',   label: 'Attention' },
  { value: 'C/O',     label: 'Care Of' },
  { value: 'BLDG',   label: 'Building'  },
  { value: 'BSMT',   label: 'Basement'  },
  { value: 'FL',     label: 'Floor'     },
  { value: 'FLT',    label: 'Flat'      },
  { value: 'HNGR',   label: 'Hanger'    },
  { value: 'LOT',    label: 'Lot'       },
  { value: 'STOP',   label: 'Stop'      },
  { value: 'TRLR',   label: 'Trailer'   },
  { value: 'UNIT',   label: 'Unit'      },
]

const streetTwoReg = /^\s*(ap(?:artmen)?t|att?e?n?ti?o?n|atntn|ba?se?me?n?t|bu?i?ldi?n?g|care\s+of|c\.?[^a-z]?o\.?|fl(?:o?o?r?|a?t)?|ha?n?ge?r|lo?t|(?:p\.?o\.?\s*)?box|p[ob]|s(?:[ui]|ui)?te?|sto?p|tr?a?i?l?e?r|uni?t)\.?\s+(.+)/i

const getDerivedStateFromValue = (value) => {
  let [ street_2 , streetTwoType , streetTwoValue ] = String(value || '').match(streetTwoReg) || []

  streetTwoType = String(streetTwoType || '').toLowerCase().replace(/[^a-z]/g, '')

  let i = 0
  while (/([a-z])[aeiou]([a-z])/.test(streetTwoType) && (i < 20)) {
    streetTwoType = streetTwoType.replace(/([a-z])[aeiou]([a-z])/g, "$1$2")
    i++
  }

  switch (streetTwoType) {
    case "apt":
    case "aprtmnt":
      streetTwoType = 'Apt'
      break;
    case "atn":
    case "attn":
    case "atntn":
    case "atttn":
    case "attntn":
      streetTwoType = 'ATTN'
      break;
    case "bldg":
    case "bldng":
      streetTwoType = 'BLDG'
      break;
    case "bsmt":
    case "bsmnt":
      streetTwoType = 'BSMT'
      break;
    case "co":
    case "cre":
      streetTwoType = 'C/O'
    case "fl":
    case "flr":
      streetTwoType = 'FL'
      break;
    case "flt":
      streetTwoType = 'FLT'
      break;
    case "hgr":
    case "hngr":
      streetTwoType = 'HNGR'
      break;
    case "lt":
      streetTwoType = 'LOT'
      break;
    case "bx":
    case "pb":
    case "po":
    case "pbx":
    case "pbox":
    case "pobox":
      streetTwoType = 'PO Box'
      break;
    case "st":
    case "ste":
      streetTwoType = 'Ste'
      break;
    case "stp":
      streetTwoType = 'STOP'
      break;
    case "tlr":
    case "trlr":
      streetTwoType = 'TRLR'
      break;
    case "unt":
      streetTwoType = 'UNIT'
      break;
    default:
      streetTwoType = ''
  }

  return {
    streetTwoError: !streetTwoType && !!value && value,
    street_2: String(street_2 || ''),
    streetTwoType,
    streetTwoValue: String(streetTwoValue || ''),
  }
}

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

    this.state = {
      ...getDerivedStateFromValue(props.street_2),
      is_foreign: !!props.is_foreign
    }
  }

  async componentDidMount(){
    try {
      return await (this.context.statesState.loaded ? Promise.resolve() : this.context.statesActions.getStates())
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate(prevProps, { streetTwoType, streetTwoValue, street_2, streetTwoError }) {
    const { street_2: propsStreet2, is_foreign } = prevProps.values || {},
          foreignChanged = (!!this.props.values && (!!this.props.values.is_foreign !== this._lastForeign))

    this._lastForeign = !this.props.values ? false : !!this.props.values.is_foreign

    if(!this.props.values || !this.props.values.is_foreign) {
      const changed = foreignChanged
        || (this.state.streetTwoType !== streetTwoType)
        || (this.state.streetTwoValue !== streetTwoValue)

      if(changed) {
        if (foreignChanged) {
          const {
                  onChange = (this.props.delegatedChange || (() => {})),
                  valuePrefix = this.props.name || '',
                } = this.props,
                methods = [
                  { method: 'Province',    value: 'province' },
                  { method: 'StreetThree', value: 'street_3' },
                ]

          methods.map(({ method, value }) => {
            const func = this.getChangeFunction(method, valuePrefix, (ev) => onChange(false, `${valuePrefix}.${value}`, ev.target.value))
            func({ target: { value: '' } })
          })

          return this.setState(getDerivedStateFromValue(this.props.values.street_2))
        } else if(streetTwoReg.test(this.state.streetTwoValue)) {
          return this.setState(getDerivedStateFromValue(this.state.streetTwoValue))
        } else if(this.state.streetTwoType && this.state.streetTwoValue) {
          return this.setState(getDerivedStateFromValue(`${this.state.streetTwoType} ${this.state.streetTwoValue}`))
        }
      } else if(this.state.street_2 !== street_2 || (streetTwoError !== this.state.streetTwoError)) {
        const {
                onChange = (this.props.delegatedChange || (() => {})),
                valuePrefix = this.props.name || '',
              } = this.props,
             func = this.getChangeFunction('StreetTwo', valuePrefix, (ev) => onChange(false, `${valuePrefix}.street_2`, ev.target.value))
        func({ target: { value: this.state.street_2 } })
      } else if(this.props.values && (propsStreet2 !== this.props.values.street_2)) {
        return this.setState(getDerivedStateFromValue(this.props.values.street_2))
      }
    } else if(foreignChanged) {
      const {
              onChange = (this.props.delegatedChange || (() => {})),
              valuePrefix = this.props.name || '',
            } = this.props,
            func = this.getChangeFunction('State', valuePrefix, (ev, option) => onChange(false, `${valuePrefix}.state_id`, (option || {}).value))

      func(null, { value: '' })

      this.setState({ streetTwoError: false })
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

  onStreetTwoTypeChange = (_, selected = {}) => {
    const { value } = selected || {}
    const streetTwoType = String(value || '')
    console.log(streetTwoType)
    this.setState({ streetTwoType })
  }
  onStreetTwoValueChange = (ev) => {
    const streetTwoValue = String(ev.currentTarget.value || '')
    this.setState({ streetTwoValue })
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

    const { streetTwoType = '', streetTwoValue = '', streetTwoError } = this.state

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
        {
          values.is_foreign
            ? (
                <>
                  <div key="street_2" className={`form-group ${values.street_2_validated && 'was-validated'}`}>
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
                  <div key="street_3" className={`form-group ${values.street_3_validated && 'was-validated'}`}>
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
                </>
              )
            : (
                <div className="row was-validated">
                  {
                    streetTwoError &&
                    (
                      <div className="col-12 form-group">
                        <div className="alert alert-danger" role="alert">
                          There was an error parsing the submitted Street 2: { streetTwoError }
                        </div>
                      </div>
                    )
                  }
                  <div className="col-lg-4 form-group">
                    <SelectField
                      key={streetTwoType ? 'street-2-type-with-value' : 'street-2-type-without-value'}
                      label="Box/Address/Attention Type"
                      id={`${id}_street_2_type`}
                      name={`${name}[street_2_type]`}
                      value={streetTwoType || ''}
                      valueKey="value"
                      onChange={this.onStreetTwoTypeChange}
                      options={streetTwoOptions}
                      viewProps={{
                        className: 'form-control',
                        required: !!streetTwoValue,
                      }}
                    />
                  </div>
                  <div className="col-lg form-group">
                    <TextField
                      label='Box/Address/Attention Value'
                      id={`${id}_street_2_value`}
                      name={`${name}[street_2_value]`}
                      type="text"
                      className="form-control"
                      value={streetTwoValue || ''}
                      onChange={this.onStreetTwoValueChange}
                      autoComplete={`${category} address-line2`}
                      required={!!streetTwoType}
                    />
                    <TextField
                      skipExtras
                      id={`${id}_street_2`}
                      name={`${name}[street_2]`}
                      type="hidden"
                      value={values.street_2}
                    />
                  </div>
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
