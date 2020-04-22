import React, { Component } from 'react'
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box';
import ShippingFields from './shipping-fields';
import Confirmation from 'common/js/forms/components/confirmation';

export default class SportFieldsComponent extends Component {
  state = { completed: false, submitting: false, checklist: false }

  get parentForm() {
    return this.props.parent || {state: {}, props: {}}
  }

  get parentState() {
    return this.parentForm.state || {}
  }

  get parentProps() {
    return this.parentForm.props || {}
  }

  get printJersey() {
    if(this.parentState.jersey_size) {
      const values = this.parentState.jersey_size.split('-')
      if(values.length === 1) return this.parentState.jersey_size
      return `${values[0] === 'M' ? "Men's/Unisex" : "Women's"} ${values[1]}`
    } else {
      return 'no'
    }
  }

  get printShorts() {
    if(this.parentState.shorts_size) {
      const values = this.parentState.shorts_size.split('-')
      if(values.length === 1) return this.parentState.shorts_size
      return `${values[0] === 'M' ? "Men's/Unisex" : "Women's"} ${values[1]}`
    } else {
      return 'no'
    }
  }

  get printShipping() {
    const { name, street_1, street_2, street_3, city, state_abbr, zip } = this.parentState.shipping || {}

    if(
      name
      && street_1
      && city
      && state_abbr
      && zip
    ) {
      return `${
        name
      }\n${
        street_1
      }\n${
        street_2 ? `${street_2}\n` : ''
      }${
        street_3 ? `${street_3}\n` : ''
      }${ city }, ${ state_abbr } ${ zip }`
    } else {
      return false
    }
  }

  componentDidMount() {
    this.parentForm.onChange('sport_id', this.parentForm.sportMappings[this.sportAbbr()])
  }

  sportAbbr = () => null
  shortsRequired = () => true
  hasNumbers = () => false

  formFields = () => (
    <div className="row">
      <div className={`col-md col-12 form-group ${this.parentState.jersey_size_validated}`}>
        <label htmlFor="uniform_order_jersey_size">
          Jersey<span className="text-danger">*</span>
        </label>
        <select
          name="uniform_order[jersey_size]"
          id="uniform_order_jersey_size"
          className="form-control"
          value={this.parentState.jersey_size || ''}
          onChange={this.onJerseyChange}
          required
        >
          <option value="" disabled="disabled"> Select Jersey Size...</option>
          {this.renderSizeOptions(true)}
        </select>
      </div>
      <div className={`col-md col-12 form-group ${this.parentState.shorts_size_validated}`}>
        <label htmlFor="uniform_order_shorts_size">
          Shorts<span className="text-danger">*</span>
        </label>
        <select
          name="uniform_order[shorts_size]"
          id="uniform_order_shorts_size"
          className="form-control"
          value={this.parentState.shorts_size || ''}
          onChange={this.onShortsChange}
          required
        >
          <option value="" disabled="disabled"> Select Shorts Size...</option>
          {this.renderSizeOptions(false)}
        </select>
      </div>
      {
        this.hasNumbers() && (
          <div className="col-12">
            <div className="row">
              { this.numberFields() }
            </div>
          </div>
        )
      }
    </div>
  )

  onJerseyChange = (ev) => {
    this.setState({checklist: false})

    this.parentForm.onChange('jersey_size', ev.currentTarget.value)
  }
  onShortsChange = (ev) => {
    this.setState({checklist: false})

    this.parentForm.onChange('shorts_size', ev.currentTarget.value)
  }
  onNumberChange = (ev) => {
    this.setState({checklist: false})

    const target = ev.currentTarget,
          val = target.value || '',
          k = `preferred_number_${target.id.replace(/[^0-9]+/, '')}`
    this.parentForm.onChange(k, val)
  }

  onSubmit = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()

    try {
      if(!this.state.checklist) {
        const checklist = []

        if(this.parentState.jersey_size) {
          checklist.push([
            `You have selected a ${this.printJersey} ${this.sportAbbr() === 'GF' ? 'polo' : 'jersey'} for ${this.parentProps.name}. Is this correct?`,
            `${this.sportAbbr() === 'GF' ? 'Polo' : 'Jersey'} size selection is required`
          ])
        } else {
          throw new Error(`${this.sportAbbr() === 'GF' ? 'Polo' : 'Jersey'} size selection is required`)
        }

        if(this.shortsRequired()) {
          if(this.parentState.shorts_size) {
            checklist.push([
              `You have selected ${this.printShorts} shorts for ${this.parentProps.name}. Is this correct?`,
              'Shorts size selection is required'
            ])
          } else {
            throw new Error('Shorts size selection is required')
          }
        }

        if(this.printShipping) {
          checklist.push([
            `You have selected to ship this order to:\n\n${this.printShipping}\n\nIs this correct?`,
            'A valid shipping address is required'
          ])
        } else {
          throw new Error('A valid shipping address is required')
        }
        this.setState({checklist})
      } else if(!this.state.checklist.length) {
        this.handleSubmit()
      }
    } catch (e) {
      this.parentForm.setState({ submitting: false, errors: [ e.toString() ], checklist: false })
    }
  }

  handleSubmit = async () => {
    try {
      const {
        sport_id = '',
        jersey_size = '',
        shorts_size = '',
        preferred_number_1 = '',
        preferred_number_2 = '',
        preferred_number_3 = '',
        shipping = {}
      } = this.parentState

      const result =  await fetch(`/api/uniform_orders/${this.parentProps.id}`, {
        method: 'PUT',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({uniform_order: { sport_id, jersey_size, shorts_size, shipping, preferred_number_1, preferred_number_2, preferred_number_3 } })
      });

      await result.json()
      this.parentForm.setState({ completed: true, submitting: false }, () => {
        this.parentProps.onSuccess && setTimeout(this.parentProps.onSuccess, 2000)
      })
    } catch(err) {
      try {
        this.parentForm.setState({errors: (await err.response.json()).errors, submitting: false})
      } catch(e) {
        this.parentForm.setState({errors: [ err.toString() ], submitting: false})
      }
    }
  }

  onConfirm = () => {
    this.setState({checklist: (this.state.checklist || []).slice(1) }, () => {
      if(!this.state.checklist.length) {
        this.handleSubmit()
      }
    })
  }

  onCancel = () => {
    const errors = [ this.state.checklist[0][1] ]
    this.setState({checklist: false })
    this.parentForm.setState({errors, submitting: false})
  }

  numberFields = () => new Array(3).fill().map((_, i) => (
    <div key={`preferred_number_${i}`} className={`col-md col-12 form-group ${this.parentState[`preferred_number_${i + 1}_validated`]}`}>
      <label htmlFor={`uniform_order_preferred_number_${i + 1}`}>
        Preferred Jersey Number { i + 1 }<span className="text-danger">*</span>
      </label>
      <input
        type="text"
        id={`uniform_order_preferred_number_${i + 1}`}
        name={`uniform_order[preferred_number_${i + 1}]`}
        className="form-control"
        value={this.parentState[`preferred_number_${i + 1}`] || ''}
        onChange={this.onNumberChange}
        inputMode="numeric"
        pattern="^[0-9]+$"
        required
      />
    </div>
  ))

  sizeOptions(label = "Men's/Unisex Sizes", max = 2, valuePrefix = ''){
    return (<optgroup key={`${label}.${max}.${valuePrefix}`} label={label}>
      <option value={`${valuePrefix}XS`}>XS</option>
      <option value={`${valuePrefix}S`}>S</option>
      <option value={`${valuePrefix}M`}>M</option>
      <option value={`${valuePrefix}L`}>L</option>
      {
        new Array(max).fill('').map((v, i) => <option key={i} value={`${valuePrefix}${(i ? i+1 : '')}XL`}>{(i ? i+1 : '')}XL</option>)
      }
    </optgroup>)
  }

  renderSizeOptions(){
    return this.sizeOptions(((this.parentForm.gender === 'M' ? "Men's/Unisex " : "Women's ") + 'Sizes'), 2, (this.parentForm.gender === 'M' ? "M-" : "W-"))
  }

  renderSizing(showWomen) {
    return <div></div>
  }

  render() {
    return this.parentState.completed ? (
      <section className="list-group-item">
        <header>
          <h3 className="mt-3 alert alert-success" role="alert">
            Uniform Order Successfully Submitted!
          </h3>
        </header>
        {
          this.parentProps.onSuccess && (
            <p>
              You will be redirected to the checklist page shortly...
            </p>
          )
        }
      </section>
    ) : (
      (this.state.checklist && this.state.checklist.length) ? (
        <Confirmation
          title="Please Review Below"
          onConfirm={this.onConfirm}
          onCancel={this.onCancel}
        >
          { this.state.checklist[0][0] }
        </Confirmation>
      ) : (
        <DisplayOrLoading
          display={!this.parentState.submitting}
          loadingElement={
            <JellyBox className="page-loader" />
          }
        >
          <form
            action={`/api/uniform_orders/${this.parentProps.id}`}
            onSubmit={this.onSubmit}
          >
            <div className="list-group-item">
              <h2 className="text-center">Sizing</h2>
              <hr/>
              <h6 className="text-center text-muted font-italic font-weight-bold">
                --- All measurements in inches unless specified ---
              </h6>
              <hr/>
              { this.renderSizing(this.parentForm.gender === 'F') }
            </div>
            <div className="list-group-item">
              <h2 className="text-center">Uniform Options</h2>
              <hr/>
              <h6 className="text-center text-muted font-italic font-weight-bold">
                --- Refer to sizing charts above ---
              </h6>
              <hr/>
              {this.formFields()}
            </div>
            <div className="list-group-item">
              <h2 className="text-center">Shipping</h2>
              <hr/>
              <h6 className="text-center text-muted font-italic font-weight-bold">
                --- Order will be shipped to the provided name &amp; address, even if a different address is tied to your account ---
              </h6>
              <hr/>
              <ShippingFields parent={this.parentForm} />
            </div>
            <div className="list-group-item">
              <div className="row">
                <div className="col">
                  <span className="text-danger">*</span> Indicates a required field
                </div>
                <div className="col-auto">
                  <button
                    className="btn btn-primary"
                    type="submit"
                  >
                    Submit Uniform Order
                  </button>
                </div>
              </div>
            </div>
            {
              this.parentState.errors && (
                <div className="list-group-item wide-label">
                  {
                    this.parentState.errors.map((err, i) => (
                      <div key={i} className="mt-3 alert alert-danger" role="alert">
                        { err }
                      </div>
                    ))
                  }
                </div>
              )
            }
          </form>
        </DisplayOrLoading>
      )
    )
  }
}
