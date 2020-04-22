import React, { Component } from 'react'
import StateSelectField from 'common/js/forms/components/state-select-field'

export default class ShippingFields extends Component {

  stateSelectProps = {
    className: 'form-control',
    autoComplete: `shipping address-level1`,
    required: false,
  }

  get parentForm() {
    return this.props.parent || {state: {}, props: {}}
  }

  get parentState() {
    return this.parentForm.state || {}
  }

  get parentProps() {
    return this.parentForm.props || {}
  }

  get shipping() {
    return (this.parentState.shipping || { country: 'USA', name: this.parentProps.name })
  }

  constructor(props) {
    super(props)
    this.validations = { name: 'was-validated' }
  }

  componentDidMount() {
    this.parentForm.onChange('shipping', this.shipping)
  }

  onChange = (ev) => {
    const target = (ev.currentTarget || {}),
          val = target.value,
          k = (target.dataset || {}).shippingKey,
          shipping = {...this.shipping, [k]: val}
    this.validations[k] = 'was-validated'
    this.parentForm.onChange('shipping', shipping)
  }

  onStateChange = (_, value) => {
    this.validations.state_abbr = 'was-validated'
    this.parentForm.onChange('shipping', {...this.shipping, state_abbr: (value || {}).abbr})
  }

  render() {
    return (
      <div className="row">
        <div className={`col-12 form-group ${this.validations.name}`}>
          <label htmlFor="uniform_order_shipping_name">
            Name<span className="text-danger">*</span>
          </label>
          <input
            type="text"
            id="uniform_order_shipping_name"
            name="uniform_order[shipping][name]"
            className="form-control"
            data-shipping-key="name"
            value={this.shipping.name || ''}
            onChange={this.onChange}
            autoComplete={`shipping name`}
            required
          />
        </div>
        {
          new Array(3).fill().map((_, i) => (
            <div key={`street.${i}`} className={`col-12 form-group ${this.validations[`street_${i + 1}`]}`}>
              <label htmlFor={`uniform_order_shipping_street_${i + 1}`}>
                Line { i + 1 }{ i === 0 ? <span className="text-danger">*</span> : '' }
              </label>
              <input
                type="text"
                id={`uniform_order_shipping_street_${i + 1}`}
                name={`uniform_order[shipping][street_${i + 1}]`}
                className="form-control"
                data-shipping-key={`street_${i + 1}`}
                value={this.shipping[`street_${i + 1}`] || ''}
                onChange={this.onChange}
                autoComplete={`shipping address-line${i + 1}`}
                required={i === 0}
              />
            </div>
          ))
        }
        <div className={`col-12 form-group ${this.validations.city}`}>
          <label htmlFor="uniform_order_shipping_city">
            City<span className="text-danger">*</span>
          </label>
          <input
            type="text"
            id="uniform_order_shipping_city"
            name="uniform_order[shipping][city]"
            className="form-control"
            data-shipping-key="city"
            value={this.shipping.city || ''}
            onChange={this.onChange}
            autoComplete={`shipping address-level2`}
            required
          />
        </div>
        <div className={`col-md col-12 form-group ${this.validations.state_abbr}`}>
          <StateSelectField
            className='form-control'
            data-shipping-key={`state_abbr`}
            onChange={this.onStateChange}
            value={this.shipping.state_abbr || ''}
            valueKey="abbr"
            autoCompleteKey="abbr"
            viewProps={this.stateSelectProps}
            id="uniform_order_shipping_state_abbr"
            name="uniform_order[shipping][state_abbr]"
            label={<span>State<span className="text-danger">*</span></span>}
            required
          />
        </div>
        <div className={`col-md col-12 form-group ${this.validations.zip}`}>
          <label htmlFor="uniform_order_shipping_zip">
            Zip Code<span className="text-danger">*</span>
          </label>
          <input
            type="text"
            id="uniform_order_shipping_zip"
            name={`uniform_order[shipping][zip]`}
            className="form-control"
            data-shipping-key="zip"
            value={this.shipping.zip || ''}
            onChange={this.onChange}
            autoComplete="shipping postal-code"
            required
          />
        </div>
        <div className="col-md col-12 form-group was-validated">
          <label htmlFor="uniform_order_shipping_country">
            Country
          </label>
          <input
            type="text"
            id="uniform_order_shipping_country"
            name={`uniform_order[shipping][country]`}
            className="form-control"
            data-shipping-key="zip"
            value="USA"
            autoComplete="shipping country"
            required
            readOnly
          />
        </div>
      </div>
    )
  }
}
