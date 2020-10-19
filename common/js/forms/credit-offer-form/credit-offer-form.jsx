import React from 'react'
import Component from 'common/js/components/component'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
//import authFetch from 'common/js/helpers/auth-fetch'

const modelAttributes = {
  credit: [],
  debit: [],
  offer: []
}

let fetchingAttributes = false

export default class CreditOfferForm extends Component {
  constructor(props) {
    super(props)

    const offer = {
      id: props.id,
      dus_id: props.dus_id,
      user: props.user,
      name: props.name || '',
      description: props.description || '',
      amount: (props.amount || {}).decimal && currencyFormat((props.amount || {}).decimal),
      rules: this.mapRules(props.rules || []),
      expiration_date: props.expiration_date || '',
      minimum: (props.minimum || {}).decimal && currencyFormat((props.minimum || {}).decimal),
      maximum: (props.maximum || {}).decimal && currencyFormat((props.maximum || {}).decimal),
    }

    console.log(offer)

    const state = {
      errors: null,
      changed: false,
      ogOffer: offer,
      form: { offer },
      addDate: props.add_date,
    }

    this.state = state
  }

  async componentDidMount(){
    await this.getModelAttributes()
  }

  getModelAttributes = async () => {
    if(fetchingAttributes) return await fetchingAttributes
    else if(modelAttributes.credit.length) return modelAttributes
    else return await(
      fetchingAttributes = new Promise(async (res, rej) => {
        const credits = await fetch('/admin/attributes/Traveler::Credit')
        modelAttributes.credit = await credits.json()
        const debits = await fetch('/admin/attributes/Traveler::Debit')
        modelAttributes.debit = await debits.json()
        const offers = await fetch('/admin/attributes/Traveler::Offer')
        modelAttributes.offer = await offers.json()
        fetchingAttributes = false
        return res(modelAttributes)
      })
    )
  }

  mapRules(rules = []){
    console.log(rules)
    const mapped = []
    for(let i = 0; i < rules.length; i++) {
      const rule = rules[i]
      switch(rule) {
        case 'offer':
        case 'credit':
        case 'debit':
          mapped.push(this.formatRule({rule, options: rules[i + 1]}))
          i++
          break;
        default:
          mapped.push(this.formatRule(rule))
          break;
      }
    }
    return mapped
  }

  unmapRules(rules = []){
    const unmapped = []
    for(let i = 0; i < rules.length; i++) {
      const {rule, options = {}} = rules[i]
      if(!rule) continue
      switch(rule) {
        case 'offer':
        case 'credit':
        case 'debit':
          unmapped.push(rule)
          unmapped.push(JSON.stringify(JSON.parse(options)))
          break;
        default:
          unmapped.push(rule)
          break;
      }
    }
    return unmapped
  }

  formatRule(rule) {
    if(typeof rule === 'string') {
      rule = {rule}
    }
    switch (rule.rule) {
      case 'offer':
      case 'credit':
      case 'debit':
        return {
          rule: rule.rule,
          options: rule.options || '{}'
        }
      default:
        return { rule: rule.rule }
    }
  }

  validJson = (val) => {
    try {
      console.log(JSON.parse(val))
      return false
    } catch(e) {
      console.log(e)
      return true
    }
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter
    console.log(v)

    if(/dus_id/.test(String(k))) {
      clearTimeout(this._checkValid)
      this._checkValid = setTimeout(this.checkCanRequest, 1500)
    }

    if(k.match(/rules\.(\d+)/)){
      console.log(k.match(/rules\.(\d+)/))
      // if(!(this.state.form.offer.rules[i + 1] || '').match(/\{\".*\":.*?\}/)) this.onChange(false, `offer.rules.${i + 1}`, '{"expiration_date":"now-30"}')
    }

    let invalid = false
    if(/\.?amount$/.test(k)) invalid = this.invalidAmount(v)
    else if(/\.?rules\.\d+\.options$/.test(k)) invalid = this.validJson(v)

    if(/\.?rules\.\d+\.rule$/.test(k)) {
      const idx = +k.match(/rules\.(\d+)/)[1],
            rule = this.formatRule({...this.state.form.offer.rules[idx], rule: v})
      return onFormChange(this, k.replace(/\.rule$/, ''), rule, true, cb)
    } else {
      return onFormChange(this, k, v, !invalid, cb)
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

  invalidAmount = (amount) => (!!(parseFloat(amount || 0, 10) < parseFloat(0, 10)))

  handleSubmit = async () => {
    try {
      if(this.invalidAmount(this.state.form.offer.amount)) {
        throw new Error('Minimum Payment Amount not met')
      }
      const form = deleteValidationKeys(Objected.deepClone(this.state.form))

      form.offer.rules = this.unmapRules(form.offer.rules)
      if(!form.offer.rules.length) throw new Error('At least one Rule must exist')

      await this.sendRequest(form)
    } catch(err) {
      await this.handleError(err)
    }
  }

  deleteOffer = async (ev) => {
    ev && ev.preventDefault()
    try {
      if(!this.props.id) return this.props.history.push(this.props.indexUrl)
      if(window.confirm("Are you sure? This cannot be undone.")) await this.sendRequest({}, true)
    } catch(err) {
      await this.handleError(err)
    }
  }

  nextRule = async (ev) => {
    ev && ev.preventDefault()
    try {
      if(!this.props.id) throw new Error('Offer Not Saved')
      if(window.confirm("Are you sure? This cannot be undone.")) await this.sendRequest({force_next: true}, false)
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

    return (await this.props.getOffers()) && this.props.history.push(this.props.indexUrl)
  }

  addRule = () => {
    this.onChange(false, 'offer.rules', [...(this.state.form.offer.rules || []), {rule: ''}])
  }

  handleError = async (err) => {
    try {
      const errorResponse = await err.response.json()
      console.log(errorResponse)
      return await this.setStateAsync({errors: errorResponse.errors || [ errorResponse.message ], submitting: false})
    } catch(e) {
      return await this.setStateAsync({errors: [ err.message ], submitting: false})
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

  columnsTable(rows) {
    return (
      <table className="table table-bordered table-striped table-sm">
        <thead>
          <tr>
            <th>
              Column Name
            </th>
            <th>
              Column Type
            </th>
          </tr>
        </thead>
        <tbody>
          <tr></tr>
        </tbody>
      </table>
    )
  }

  getKeys(rule) {
    return (
      <table className="table table-bordered table-striped table-sm mt-3">
        <thead>
          <tr>
            <th>
              Column Name
            </th>
            <th>
              Column Type
            </th>
          </tr>
        </thead>
        <tbody>
          {
            (modelAttributes[rule] || []).map(({name, type}, k) => (
              <tr key={k}>
                <th>{name}</th>
                <td>{type}</td>
              </tr>
            ))
          }
        </tbody>
      </table>
    )
    // switch(rule) {
    //   case 'offer':
    //     return 'rules (array), amount (cents), minimum (cents), maximum (cents), expiration_date (date | calculated), name (text), description (text), created_at (date | calculated)'
    //   case 'credit':
    //     return 'amount (cents), name (text), description (text), created_at (date | calculated)'
    //   case 'debit':
    //     return 'base_debit_id (integer), amount (cents), name (text), description (text), created_at (date | calculated)'
    // }
  }

  render(){
    const { url } = this.props,
          autoComplete = new Date()


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
          className='credit-offer-form mb-3'
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
                      fields: [
                        {
                          field: 'TextField',
                          wrapperClass: `col-md-6 form-group ${this.state.form.offer.amount_validated ? 'was-validated' : ''}`,
                          label: 'Amount',
                          name: 'offer.amount',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.offer.amount || '',
                          useCurrencyFormat: true,
                          onChange: true,
                          placeholder: '200.0',
                          autoComplete: `invalid ${autoComplete}`,
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-md-6 form-group ${this.state.form.offer.name_validated ? 'was-validated' : ''}`,
                          label: 'Name',
                          name: 'offer.name',
                          type: 'text',
                          value: this.state.form.offer.name || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          placeholder: 'Instant Discount',
                          feedback: 'Enter a name',
                          required: true
                        },
                        {
                          field: 'TextAreaField',
                          wrapperClass: `col-12 form-group ${this.state.form.offer.description_validated ? 'was-validated' : ''}`,
                          label: 'Description',
                          name: 'offer.description',
                          type: 'text',
                          value: this.state.form.offer.description || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          feedback: 'Enter a description',
                          required: false
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-4 col-md-6 form-group ${this.state.form.offer.minimum_validated ? 'was-validated' : ''}`,
                          label: 'Minimum',
                          name: 'offer.minimum',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.offer.minimum || '',
                          useCurrencyFormat: true,
                          onChange: true,
                          placeholder: '200.0',
                          autoComplete: `invalid ${autoComplete}`,
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-4 col-md-6 form-group ${this.state.form.offer.maximum_validated ? 'was-validated' : ''}`,
                          label: 'Maximum',
                          name: 'offer.maximum',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.offer.maximum || '',
                          useCurrencyFormat: true,
                          onChange: true,
                          placeholder: '200.0',
                          autoComplete: `invalid ${autoComplete}`,
                          required: true
                        },
                        {
                          field: 'CalendarField',
                          wrapperClass: `col-lg-4 col-md-6 form-group ${this.state.form.offer.expiration_date_validated ? 'was-validated' : ''}`,
                          label: 'Expiration Date (YYYY-MM-DD)',
                          name: 'offer.expiration_date',
                          type: 'text',
                          value: this.state.form.offer.expiration_date,
                          valueKey: 'value',
                          pattern: "\\d{4}-\\d{2}-\\d{2}",
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          size: 75
                        },
                        {
                          className: 'col-12',
                          fields:[
                            ...(
                              this.state.form.offer.rules.map(({
                                rule,
                                rule_valid,
                                rule_validated,
                                options,
                                options_valid,
                                options_validated
                              }, i) => ({
                                className: 'row',
                                fields: [
                                  {
                                    field: 'SelectField',
                                    wrapperClass: `col-12 form-group ${rule_validated ? 'was-validated' : ''}`,
                                    viewProps: {
                                      className: 'form-control',
                                      autoComplete: `invalid ${autoComplete}`,
                                    },
                                    label: `Offer Rule ${i + 1}`,
                                    name: `offer.rules.${i}.rule`,
                                    type: 'text',
                                    value: rule || '',
                                    onChange: true,
                                    autoComplete: `invalid ${autoComplete}`,
                                    feedback: 'Enter a valid offer rule',
                                    required: false,
                                    valueKey:'value',
                                    options: [
                                      'alternate',
                                      'balance',
                                      'credit',
                                      'debit',
                                      'deposit',
                                      'destroy',
                                      'offer',
                                      'payment',
                                      'percentage',
                                      'signup',
                                      'placeholder',
                                    ]
                                  },
                                  ...(
                                    options ? [
                                      {
                                        className:'row',
                                        wrapperClass: `col-12`,
                                        fields: [
                                          {
                                            field: 'TextField',
                                            wrapperClass: `col-12 form-group`,
                                            className: `form-control ${options_validated ? (options_valid ? 'is-valid' : 'is-invalid') : ''}`,
                                            label: `Rule ${i + 1} Options`,
                                            name: `offer.rules.${i}.options`,
                                            type: 'text',
                                            value: options,
                                            onChange: true,
                                            autoComplete: `invalid ${autoComplete}`,
                                            feedback: this.getKeys(rule),
                                            required: false
                                          },

                                        ]
                                      }
                                    ] : []
                                  )
                                ]
                              })
                            ))
                          ]
                        }
                      ]
                    },
                    {
                      className: 'row',
                      fields: [
                        {
                          field: 'button',
                          wrapperClass: 'col form-group',
                          className: 'btn btn-info btn-block',
                          type: 'button',
                          onClick: this.addRule,
                          children: 'Add Rule'
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
                          onClick: this.deleteOffer,
                          children: 'Delete Offer'
                        },
                        {
                          field: 'button',
                          wrapperClass: 'col-auto form-group',
                          className: 'btn btn-warning btn-lg active',
                          type: 'button',
                          onClick: this.nextRule,
                          children: 'Force Next Rule'
                        },
                        {
                          field: 'button',
                          wrapperClass: 'col form-group',
                          className: 'btn btn-primary btn-lg active float-right',
                          type: 'submit',
                          children: 'Submit Offer'
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
