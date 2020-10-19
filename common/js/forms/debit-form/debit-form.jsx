import React from 'react'
import Component from 'common/js/components/component'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
//import authFetch from 'common/js/helpers/auth-fetch'


export default class DebitForm extends Component {
  constructor(props) {
    super(props)

    const debit = {
      id: props.id,
      base_debit_id: props.base_debit_id,
      dus_id: props.dus_id,
      user: props.user,
      name: props.name !== props.base_debit.name ? props.name : void(0),
      description: props.description !== props.base_debit.description ? props.description : void(0),
      amount: props.amount.decimal && currencyFormat(props.amount.decimal),
    }

    const state = {
      errors: null,
      changed: false,
      baseDebit: props.base_debit || {},
      addDate: props.add_date,
      form: { debit }
    }
    state.ogDebit = { ...debit, baseDebit: state.baseDebit }

    if(this.isAirfare(state.baseDebit || {})) {
      console.log("IS AIRFARE")
      const matches = /:\s+([A-Z]{3})-([A-Z]{3})$/.exec(props.name || '')
      this.ogDeparting = state.form.departing = matches[1] || ''
      this.ogReturning = state.form.returning = matches[2] || ''
      state.form.debit.amount = ''
    } else if(this.isAdditionalSport(state.baseDebit || {})) {
      const splitDesc = String(props.description || '').split("\n"),
            sport = splitDesc.shift(),
            description = splitDesc.join('\n') || void(0)
      state.form.sport = sport
      state.form.debit.description = description
    }

    this.state = state
  }

  async componentDidMount() {
    await Component.prototype.componentDidMount.call(this)
    this.focusNewDebit()
  }

  focusNewDebit = () => {
    if(!this.baseDebitEl) return setTimeout(this.focusNewDebit, 10)
    if(/new/i.test(this.props.id) || ("undefined" === typeof this.props.id)) this.baseDebitEl.focus()
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter

    if(/dus_id/.test(String(k))) {
      clearTimeout(this._checkValid)
      this._checkValid = setTimeout(this.checkCanRequest, 1500)
    }

    return onFormChange(this, k, v, !(/\.?amount$/.test(k) && this.invalidAmount(v)), cb)
  }

  changeBaseDebit = async (a, name, baseDebit) => {
    if(baseDebit.value !== this.state.baseDebit.id) {
      baseDebit = this.props.baseDebits.find(({id}) => `${id}` === `${baseDebit.value}`)
      if(baseDebit) {
        await this.setStateAsync({ baseDebit })
        await this.onChange(a, name, baseDebit.id)
        await this.onChange(a, 'debit.amount', this.isManaged(baseDebit) ? '' : currencyFormat(baseDebit.amount.decimal))
        await this.onChange(a, 'debit.name', '')
        await this.onChange(a, 'debit.description', '')
        await this.onChange(a, 'sport', void(0))
        await this.onChange(a, 'departing', void(0))
        await this.onChange(a, 'returning', void(0))
      } else {
        this.setState({
          errors: [
            ...(this.state.errors || []),
            'Invalid Base Debit'
          ]
        })
      }

    }
  }

  validate(k, regex) {
    if(!regex.test(k)) {
      this.setState({[k + '_valid']: false})
    }
  }

  onSubmit = (e) => {
    e && e.preventDefault();
    this.setState({submitting: true}, () => this.handleSubmit())
  }

  isAirfare = (bd) => /^(Domestic|Additional) Airfare$/.test((bd || this.state.baseDebit).name || '')
  isInsurance = (bd) => "Travelex Insurance" === (bd || this.state.baseDebit).name
  isAdditionalSport = (bd) => "Additional Sport" === (bd || this.state.baseDebit).name
  isManaged = (bd) => this.isInsurance(bd) || this.isAirfare(bd) || this.isAdditionalSport(bd)

  invalidAmount = (amount) => !!(parseFloat(amount || 0, 10) < parseFloat(0, 10))

  handleSubmit = async () => {
    try {
      if(this.invalidAmount(this.state.form.debit.amount)) {
        throw new Error('Minimum Payment Amount not met')
      }
      const form = deleteValidationKeys(Objected.deepClone(this.state.form))

      if(this.isAirfare()) {
        form.airfare = 1
      } else if(this.isInsurance()) {
        form.insurance = 1
      }

      await this.sendRequest(form)
    } catch(err) {
      await this.handleError(err)
    }
  }

  baseDebitAmount = () => currencyFormat((this.state.baseDebit.amount && this.state.baseDebit.amount.decimal) || '0')

  airfareDebitAmount = () => this.isOriginalAirfare() ? currencyFormat(this.state.ogDebit.amount || '0') : ''

  isOriginalAirfare = () =>
    this.isAirfare(this.state.ogDebit.baseDebit || {})
    && (this.ogDeparting === this.state.form.departing)
    && (this.ogReturning === this.state.form.returning)

  deleteDebit = async (ev) => {
    ev && ev.preventDefault()
    try {
      if(!this.props.id) return this.props.history.push(this.props.indexUrl)
      if(window.confirm("Are you sure? This cannot be undone.")) await this.sendRequest({}, true)
    } catch(err) {
      await this.handleError(err)
    }
  }

  sendRequest = async (form, deleting = false) => {
    await this.setStateAsync({ submitting: true })

    await fetch(this.props.url, {
      method: deleting ? 'DELETE' : (this.props.id ? 'PATCH' : 'POST'),
      headers: {
        "Content-Type": "application/json; charset=utf-8"
      },
      body: JSON.stringify(form)
    })

    return (await this.props.getDebits()) && this.props.history.push(this.props.indexUrl)
  }

  handleError = async (err) => {
    try {
      const errorResponse = await err.response.json()
      console.log(errorResponse)
      return await this.setStateAsync({errors: errorResponse.errors || [ errorResponse.message ], submitting: false})
    } catch(e) {
      return await this.setStateAsync({errors: [ err.message || err.toString() ], submitting: false})
    }
  }

  baseDebitRef = (el) => this.baseDebitEl = el

  mainForm = () => [
    ...(
      this.isManaged() ? [] : [
        {
          field: 'TextField',
          wrapperClass: `col-md-6 form-group ${this.state.form.debit.amount_validated ? 'was-validated' : ''}`,
          label: `Debit Amount (Base: $${this.baseDebitAmount()})`,
          name: 'debit.amount',
          type: 'text',
          inputMode: 'numeric',
          value: this.state.form.debit.amount || '',
          useCurrencyFormat: true,
          onChange: true,
          autoComplete: 'off',
          placeholder: this.baseDebitAmount(),
          required: true
        },
        {
          field: 'TextField',
          wrapperClass: `col-md-6 form-group ${this.state.form.debit.name_validated ? 'was-validated' : ''}`,
          label: 'Debit Name Override',
          name: 'debit.name',
          type: 'text',
          value: this.state.form.debit.name || '',
          onChange: true,
          autoComplete: 'off',
          placeholder: this.state.baseDebit.name,
          feedback: 'Enter an name here to override the debit name',
          required: false
        },
        {
          field: 'TextAreaField',
          wrapperClass: `col-12 form-group ${this.state.form.debit.description_validated ? 'was-validated' : ''}`,
          label: 'Debit Description Override',
          name: 'debit.description',
          type: 'text',
          value: this.state.form.debit.description || '',
          onChange: true,
          autoComplete: 'off',
          placeholder: this.state.baseDebit.description,
          feedback: 'Enter an name here to override the debit description',
          required: false
        },
      ]
    ),
  ]

  airfareForm = () => [
    {
      field: 'AirportSelectField',
      wrapperClass: `col-md-6 form-group ${this.state.form.departing_validated ? 'was-validated' : ''}`,
      name: 'departing',
      label: 'Departing From (Three Letter Abbr)',
      viewProps: {
        autoComplete: 'off',
        className: 'form-control',
        placeholder: 'LAX',
        required: true
      },
      valueKey: 'value',
      onChange: true,
      value: this.state.form.departing || '',
      required: true
    },
    {
      field: 'AirportSelectField',
      wrapperClass: `col-md-6 form-group ${this.state.form.returning_validated ? 'was-validated' : ''}`,
      label: 'Returning To (Leave Blank if Same)',
      name: 'returning',
      viewProps: {
        autoComplete: 'off',
        className: 'form-control',
        placeholder: this.state.form.departing || 'LAX',
      },
      valueKey: 'value',
      onChange: true,
      value: this.state.form.returning || '',
    },
    {
      field: 'TextField',
      wrapperClass: `col-md-6 form-group ${this.state.form.debit.amount_validated ? 'was-validated' : ''}`,
      label: `Override Airfare Amount`,
      name: 'debit.amount',
      type: 'text',
      inputMode: 'numeric',
      value: this.state.form.debit.amount || '',
      useCurrencyFormat: true,
      onChange: true,
      autoComplete: 'off',
      placeholder: this.airfareDebitAmount(),
      required: false
    },
  ]

  sportForm = () => [
    {
      key: this.state.form.sport || 'select-sport',
      field: 'SportSelectField',
      wrapperClass: `col-md-6 form-group ${this.state.form.sport_validated ? 'was-validated' : ''}`,
      name: 'sport',
      label: 'Sport',
      viewProps: {
        autoComplete: 'off',
        className: 'form-control',
        placeholder: 'GBB',
        required: true
      },
      valueKey: 'label',
      onChange: true,
      value: this.state.form.sport || '',
      required: true
    },
    {
      field: 'TextField',
      wrapperClass: `col-md-6 form-group ${this.state.form.debit.amount_validated ? 'was-validated' : ''}`,
      label: `Override Price (${this.state.baseDebit.amount.str_pretty}) `,
      name: 'debit.amount',
      type: 'text',
      inputMode: 'numeric',
      value: this.state.form.debit.amount || '',
      useCurrencyFormat: true,
      onChange: true,
      autoComplete: 'off',
      placeholder: this.baseDebitAmount(),
      required: false
    },
    {
      field: 'TextAreaField',
      wrapperClass: `col-12 form-group ${this.state.form.debit.description_validated ? 'was-validated' : ''}`,
      label: 'Custom Description',
      name: 'debit.description',
      type: 'text',
      value: this.state.form.debit.description || '',
      onChange: true,
      autoComplete: 'off',
      placeholder: this.state.baseDebit.description,
      feedback: 'Add additional description lines here',
      required: false
    },
  ]

  getForm = () => {
    switch (true) {
      case this.isAirfare():
        return this.airfareForm();
      case this.isAdditionalSport():
        return this.sportForm();
      default:
        return this.mainForm()
    }
  }

  renderErrors() {
    return (
      <div className="row">
        <div className="col">
          {
            this.state.errors && <div className="alert alert-danger form-group" role="alert">
              {
                this.state.errors.map((v, k) => (
                  <div className='row' key={k}>
                    <div className="col">
                      { v }
                    </div>
                  </div>
                ))
              }
            </div>
          }
        </div>
      </div>
    )
  }

  render(){
    const { url } = this.props

    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        <form
          action={url}
          method='post'
          className='debit-form mb-3'
          onSubmit={this.onSubmit}
          autoComplete="off"
        >
          <input autoComplete="false" type="text" name="autocomplete" style={{display: 'none'}}/>
          {this.renderErrors()}
          <section>
            <div className='main m-0'>
              <DisplayOrLoading display={!this.state.checkingId}>
                <FieldsFromJson
                  onChange={this.onChange}
                  form='payment'
                  fields={[
                    {
                      className: 'row',
                      fields: this.state.addDate ? [
                        {
                          field: 'h4',
                          wrapperClass: 'col text-center',
                          children: `Add Date: ${this.state.addDate}`
                        }
                      ] : []
                    },
                    {
                      className: 'row',
                      fields: [
                        {
                          field: 'SelectField',
                          wrapperClass: 'col-12 form-group',
                          name: 'debit.base_debit_id',
                          label: 'Base Debit',
                          viewProps: {
                            className: 'form-control',
                            autoComplete: 'off',
                            required: true,
                          },
                          onChange: true,
                          changeOverride: this.changeBaseDebit,
                          value: this.state.form.debit.base_debit_id,
                          options: this.props.baseDebits.map((bd) => ({
                            value: bd.id,
                            label: `${bd.name}${bd.description ? ` - ${bd.description}` : ''}`,
                          })),
                          filterOptions: { indexes: [ 'label' ] },
                          ref: this.baseDebitRef
                        },
                      ]
                    },
                    {
                      className: 'row',
                      fields: [
                        ...this.getForm(),
                        {
                          field: 'CalendarField',
                          wrapperClass: `col-lg-6 col-md-8 form-group ${this.state.form.debit.created_at_override_validated ? 'was-validated' : ''}`,
                          label: 'Override Applied Date (YYYY-MM-DD)',
                          name: 'debit.created_at_override',
                          type: 'text',
                          value: this.state.form.debit.created_at_override || '',
                          valueKey: 'value',
                          pattern: '[0-9]{4}-[0-9]{2}-[0-9]{2}',
                          onChange: true,
                          autoComplete: 'off',
                          required: false,
                        },
                      ]
                    },
                    {
                      field: 'hr'
                    },
                    {
                      className: 'row',
                      fields: [
                        {
                          field: 'button',
                          wrapperClass: 'col form-group',
                          className: 'btn btn-danger btn-lg active float-left',
                          type: 'button',
                          onClick: this.deleteDebit,
                          children: 'Delete Debit'
                        },
                        {
                          field: 'button',
                          wrapperClass: 'col form-group',
                          className: 'btn btn-primary btn-lg active float-right',
                          type: 'submit',
                          children: 'Submit Debit'
                        }
                      ]
                    },
                  ]}
                />
                {this.renderErrors()}
              </DisplayOrLoading>
            </div>
          </section>
        </form>
      </DisplayOrLoading>
    )
  }
}
