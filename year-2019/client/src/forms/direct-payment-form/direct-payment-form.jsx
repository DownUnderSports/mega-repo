import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
//import authFetch from 'common/js/helpers/auth-fetch'
import canUseDOM from 'common/js/helpers/can-use-dom'
import dusIdFormat from 'common/js/helpers/dus-id-format'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import { userIsValid, getUserName, baseErrorLink } from 'common/js/components/find-user';
import { emailRegex } from 'common/js/helpers/email';


const directTypes = [
        {value: 'ach', label: 'ACH Payment'},
        {value: 'cash', label: 'Cash Payment'},
        {value: 'card', label: 'Card Payment'},
        {value: 'check', label: 'Check Payment'},
      ],
      baseState = {
        submitting: false,
        receiptId: null,
        errors: null,
        changed: false,
        form: {
          payment: {
            gateway: {},
            transaction_type: '',
            amount: '',
            date_entered: '',
            time_entered: '',
            remit_number: '',
            checks: [],
          },
        }
      }


export default class DirectPaymentForm extends Component {
  constructor(props) {
    super(props)

    this.state = Objected.deepClone(baseState)

    this.action = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/accounting/checks`
  }

  lookupUser = (ev, k) => {
    this.onChange(ev, k, false, async () => {
      const formatted = dusIdFormat(Objected.getValue(this.state.form, k))
      if( formatted.length > 6 ) {
        try {
          const valid = await userIsValid(formatted)
          if(formatted === dusIdFormat(Objected.getValue(this.state.form, k))) {
            this.setState(state => {
              if(formatted === dusIdFormat(Objected.getValue(state.form, k))) {
                const form = { ...state.form }
                Objected.setValue(form, `${k}_valid`, !!valid)
                Objected.setValue(form, `${k}_valid_name`, valid ? '' : 'Not Found')
                return { form }
              } else {
                return {}
              }
            })
            if(valid) {
              const name = await getUserName(formatted)
              if(formatted === dusIdFormat(Objected.getValue(this.state.form, k))) {
                this.setState(state => {
                  if(formatted === dusIdFormat(Objected.getValue(state.form, k))) {
                    const form = { ...state.form }
                    Objected.setValue(form, `${k}_valid_name`, name)
                    return { form }
                  } else {
                    return {}
                  }
                })
              }
            }
          }
        } catch(e) {
          let link = baseErrorLink.replace('|PAGE_ERROR|', encodeURIComponent(e.toString() || '')).replace('|USER_AGENT|', encodeURIComponent((window.navigator || {}).userAgent))
          try {
            let linkWithHistory = link.replace(/CONSOLE%3A%20.*/, encodeURIComponent('CONSOLE: ' + JSON.stringify(console.history || [])))
            link = linkWithHistory
          } catch (err) {
          }
          if(link && window.confirm(`The following error occured when attempting to find the requested user: ${e.toString()}. Would you like to report this error?`)) {
            window.location.href = link
          }
        }

      }
    })
  }

  allowNext = () => {
    const values = this.state.form.payment
    return !!values.amount
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter

    return onFormChange(this, k, v, !(/\.?amount$/.test(k) && this.invalidAmount(v)), cb)
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

  invalidAmount = (amount) => !!(parseFloat(amount || 0, 10) < parseFloat(1, 10))

  handleSubmit = async () => {
    if(!this.state.changed) return this.props.onSuccess && this.props.onSuccess(this.state.receiptId)
    try {
      if(this.state.form.payment.checks.some((c) => !c.dus_id && !!c.amount)) {
        throw new Error('Not all DUS IDs entered')
      }
      if(this.state.form.payment.checks.some((c) => !c.billing.name && !!c.amount)) {
        throw new Error('Billing name is required for all entries')
      }
      if(this.invalidAmount(this.state.form.payment.amount)) {
        throw new Error('Minimum Payment Amount not met')
      }
      const form = deleteValidationKeys(Objected.deepClone(this.state.form))

      const result =  await fetch(this.action, {
              method: 'POST',
              headers: {
                "Content-Type": "application/json; charset=utf-8"
              },
              body: JSON.stringify(form)
            }),
            json = await result.json(),
            payments = json.payments || [],
            checks = form.payment.checks,
            receipts = [],
            errors = []

      let successful = true

      for(let i = payments.length; i > 0; i--) {
        const pmt = payments[i - 1]
        if(pmt.status < 300) {
          receipts.push(pmt.json.id)
          checks.splice(i - 1, 1)
        } else {
          successful = false
          errors.push(...pmt.json.errors)
        }
      }


      if(successful) {
        this.setState({...baseState, receipts, successful})
      } else {
        this.setState({form, errors, successful, submitting: false})
      }
    } catch(err) {
      try {
        const errorResponse = await err.response.json()
        console.log(errorResponse)
        this.setState({errors: errorResponse.errors || [ errorResponse.message ], submitting: false})
      } catch(e) {
        this.setState({errors: [ err.message ], submitting: false})
      }
    }
  }

  noAddress = (i) => {
    if(!this.state.form.payment.checks[i].dus_id) {
      alert('DUS_ID not entered')
    } else {
      this.setState({submitting: true}, async () => {
        try {
          const form = Objected.deepClone(this.state.form),
                check = form.payment.checks[i],
                dusId = dusIdFormat(check.dus_id),
                result = await fetch(`${canUseDOM ? '' : 'http://localhost:3000'}/admin/users/${dusId}/main_address`),
                address = (await result.json()).address || {};

          check.dus_id = dusId
          check.billing = {
            company: '',
            name: address.name,
            email: address.email,
            phone: address.phone,
            country_code_alpha3: 'USA',
            street_address: address.street || 'Unavailable',
            extended_address: (address.street_2 || '') && (address.street_2 + (address.street_3 ? `, ${address.street_3}` : '')),
            locality: address.city || 'North Logan',
            region: address.state || address.province || 'UT',
            postal_code: address.zip || '84341',
          }

          this.setState({form, submitting: false})
        } catch (e) {
          console.error(e)
          this.setState({submitting: false})
        }
      })
    }
  }

  addCheck = () => {
    const form = Objected.deepClone(this.state.form),
          checks = form.payment.checks;

    checks.push({
      dus_id: '',
      date_entered: '',
      time_entered: '',
      amount: '',
      transaction_type: 'cash',
      billing: {
        company: '',
        name: '',
        email: '',
        phone: '',
        country_code_alpha3: 'USA',
        extended_address: '',
        locality: '',
        postal_code: '',
        region: '',
        street_address: '',
      },
      gateway: {
        transaction_type: 'direct',
        routing_number: '',
        account_number: '',
        check_number: `${checks.length + 1}`.rjust(4, '0'),
        send_email: false,
      },
      split: [],
    })

    this.setState({form})

  }

  removeCheck = (i, e) => {
    if(e) {
      e.preventDefault()
      e.stopPropagation()
    }

    this.setState(state => {
      const form = Objected.deepClone(state.form)
      form.payment.checks.splice(i, 1)
      return { form }
    })
  }

  addSplit = (i) => {
    let form = Objected.deepClone(this.state.form),
        split = form.payment.checks[i].split;

    split.push({
      dus_id: '',
      amount: ''
    })

    this.setState({form})

  }

  americanToUniversal(am){
    am = `${am || ''}`.trim().split('/')
    return `${(am[2] || '')}-${(am[0] || '').rjust(2, '0')}-${(am[1] || '').rjust(2, '0')}`
  }

  splitLine(l) {
    return `${l || ''}`.replace(/\s+/g, ' ').replace(/[^ 0-9.]/g, '').split(' ')
  }

  parseChecksPaste = (ev) => {
    const rawZions = ev.target.value.replace(/\n\n/g, "\n"),
          lines = rawZions.split(/\n/)

    const form = Objected.deepClone(this.state.form)
    let lastLine = null

    form.payment.checks.splice(0, form.payment.checks.length)
    form.payment.transaction_type = 'check'
    form.payment.gateway.transaction_type = 'direct'

    for(let i = 0; i < lines.length; i++) {
      const line = lines[i]

      if(lastLine === 'depositInfo') {
        const row = this.splitLine(line)
        form.payment.amount = currencyFormat(row[2])
        form.payment.gateway.deposit_number = row[0]
        form.payment.gateway.deposited_items = row[1]
        lastLine = null
      } else if(lastLine === 'itemInfo') {
        lastLine = 'itemInfoCredit'
      } else if(lastLine === 'itemInfoCredit') {
        const row = this.splitLine(line)

        console.log(line, row)

        if(row.length > 7) {
          const tmp = [...row]
          row[2] = tmp[row.length - 2]
          row[3] = tmp[2]
          row[4] = tmp.slice(3, row.length - 2).join('')
        } else if(row.length === 4 && /\d+\.\d{2}/.test(row[row.length - 1])) {
          row.splice(3, 0, '', ...row.splice(2))
          console.log(row)
        } else if(row[4].length < 4 && row[5].length > 4) {
          let tmp = row[5]
          row[5] = row[4]
          row[4] = tmp
        }

        row[2] = row[2].replace(/^0+/, '')


        form.payment.checks.push({
          dus_id: '',
          date_entered: form.payment.date_entered || '',
          time_entered: form.payment.time_entered || '',
          amount: currencyFormat(row[row.length - 1] || ''),
          transaction_type: 'check',
          billing: {
            company: '',
            name: '',
            email: '',
            phone: '',
            country_code_alpha3: 'USA',
            extended_address: '',
            locality: '',
            postal_code: '',
            region: '',
            street_address: '',
          },
          gateway: {
            transaction_type: 'direct',
            routing_number: row[3],
            account_number: row[4].slice(row[4].length - 4),
            check_number: row[2],
            send_email: false,
          },
          split: [],
        })

        if(!(/^\s*DEBIT/).test(lines[i+1])) lastLine = null

      } else if((/current\s+date.time:.*?[A-Z]{3}\s*$/i).test(line)) {
        const date = line.match(/current\s+date.time:\s+(.*)\s+[A-Z]{3}\s*$/i)[1].trim().split(/\s+/)
        form.payment.date_entered = this.americanToUniversal(date[0])
        form.payment.time_entered = date[1].trim()
        form.payment.remit_number = `${form.payment.date_entered}-CHECK`
      } else if((/transfer\s+status:\s+[a-z]+\s*$/i).test(line)) {
        form.payment.status = line.match(/transfer\s+status:\s+([a-z]+)\s*$/i)[1].trim()
      } else if((/deposit\s+#\s+deposited\s+items/i).test(line)) {
        lastLine = 'depositInfo'
      } else if((/item\s+type\s+item\s+#\s+aux/i).test(line)) {
        lastLine = 'itemInfo'
      }
    }

    this.setState({form})
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

  renderSuccess() {
    return (
      <div className="row">
        <div className="col">
          <div className="alert alert-success form-group" role="alert">
            Payment(s) Submitted Successfully
          </div>
        </div>
      </div>
    )
  }

  renderReceipts() {
    return (
      <div className="row">
        <div className="col">
          {
            (
              this.state.receipts && this.state.receipts.length && (
                <div className="alert alert-success form-group" role="alert">
                  {
                    this.state.receipts && this.state.receipts.map((v, k) => (
                      <div className='row form-group' key={k}>
                        <div className="col">
                          <Link className='btn btn-secondary btn-block' to={`https://downundersports.com/payment/${v}`} target='_view_receipt'>View Receipt: {v}</Link>
                        </div>
                      </div>
                    ))
                  }
                </div>
              )
            ) || ''
          }
        </div>
      </div>
    )
  }

  render(){
    const autoComplete = new Date()

    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        {
          this.state.successful && this.renderSuccess()
        }
        {this.renderReceipts()}
        {this.renderErrors()}
        <form
          action={this.action}
          method='post'
          className='payment-form mb-3'
          onSubmit={this.onSubmit}
          autoComplete="off"
        >
          <input autoComplete="false" type="text" name="autocomplete" style={{display: 'none'}}/>
          <section>
            <div className='main m-0'>
              <DisplayOrLoading display={!this.state.checkingId}>
                <FieldsFromJson
                  onChange={this.onChange}
                  form=''
                  fields={[
                    {
                      className: 'row',
                      fields: [
                        {
                          field: 'TextAreaField',
                          wrapperClass: `col-12 form-group`,
                          className: 'form-control',
                          label: 'PASTE PAGE COPY',
                          type: 'text',
                          value: this.state.rawZions || '',
                          onChange: true,
                          changeOverride: this.parseChecksPaste,
                          autoComplete: `invalid ${autoComplete}`,
                          name: 'rawZions'
                        },
                      ]
                    },
                    {
                      className: 'row',
                      fields: [
                        {
                          field: 'TextField',
                          wrapperClass: `col-md-6 form-group ${this.state.form.payment.amount_validated ? 'was-validated' : ''}`,
                          label: 'Payment Amount*',
                          name: 'payment.amount',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.payment.amount || '',
                          useCurrencyFormat: true,
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          placeholder: '(300.00)',
                          feedback: `Total Amount on Check/ACH`,
                          required: true
                        },
                        ...(
                          this.allowNext() ? [
                            {
                              field: 'TextField',
                              wrapperClass: `col-md-6 form-group ${this.state.form.payment.status_validated ? 'was-validated' : ''}`,
                              label: 'Status',
                              name: 'payment.status',
                              placeholder: '(Posted)',
                              type: 'text',
                              value: this.state.form.payment.status || '',
                              onChange: true,
                              autoComplete: `invalid ${autoComplete}`,
                              required: true,
                            },
                            {
                              field: 'TextField',
                              wrapperClass: `col-md-6 form-group ${this.state.form.payment.remit_number_validated ? 'was-validated' : ''}`,
                              label: 'Remit Number',
                              name: 'payment.remit_number',
                              placeholder: '(Posted)',
                              type: 'text',
                              value: this.state.form.payment.remit_number || '',
                              onChange: true,
                              autoComplete: `invalid ${autoComplete}`,
                              required: true,
                            },
                            {
                              wrapperClass: 'col-12',
                              field: 'hr'
                            },
                            ...(
                              this.state.form.payment.checks.map(
                                (check, c) => ({
                                  className: 'border rounded p-3',
                                  wrapperClass: 'col-lg-6 form-group',
                                  fields: [
                                    {
                                      className: 'row',
                                      fields: [
                                        {
                                          field: 'button',
                                          type: 'button',
                                          onClick: (e) => this.removeCheck(c, e),
                                          wrapperClass: 'col',
                                          className: 'btn btn-danger float-right',
                                          children: 'Remove'
                                        },
                                        {
                                          field: 'h3',
                                          className: 'col-12 text-center form-group',
                                          children: `${check.transaction_type && `${check.transaction_type[0].toUpperCase()}${check.transaction_type.slice(1)}`} ${check.gateway.check_number} ($${check.amount})`
                                        },
                                        {
                                          className: 'col-12',
                                          fields: [
                                            {
                                              className: 'row',
                                              fields: [
                                                {
                                                  field: 'TextField',
                                                  wrapperClass: `col-6 form-group ${check.check_number_validated ? 'was-validated' : ''}`,
                                                  label: `Check Number`,
                                                  name: `payment.checks.${c}.gateway.check_number`,
                                                  type: 'text',
                                                  value: check.gateway.check_number || '',
                                                  onChange: true,
                                                  autoComplete: `invalid ${autoComplete}`,
                                                },
                                                {
                                                  className: `col-6 form-group`,
                                                  fields: [
                                                    {
                                                      field: 'TextField',
                                                      wrapperClass: 'mb-1',
                                                      className: `form-control ${check.dus_id_validated ? (check.dus_id_valid ? 'is-valid' : 'is-invalid') : ''}`,
                                                      label: `DUS ID* (${check.dus_id_valid_name || 'required' })`,
                                                      name: `payment.checks.${c}.dus_id`,
                                                      type: 'text',
                                                      value: check.dus_id || '',
                                                      onChange: true,
                                                      changeOverride: this.lookupUser,
                                                      autoComplete: `invalid ${autoComplete}`,
                                                      required: !!(+check.amount > 0)
                                                    },
                                                    {
                                                      className: 'text-center',
                                                      children: check.dus_id_valid_name,
                                                    },
                                                  ]
                                                },
                                                {
                                                  field: 'TextField',
                                                  wrapperClass: `col-6 form-group ${check.amount_validated ? 'was-validated' : ''}`,
                                                  label: 'Payment Amount*',
                                                  name: `payment.checks.${c}.amount`,
                                                  type: 'text',
                                                  inputMode: 'numeric',
                                                  value: check.amount || '',
                                                  useCurrencyFormat: true,
                                                  onChange: true,
                                                  autoComplete: `invalid ${autoComplete}`,
                                                  placeholder: '(300.00)',
                                                  feedback: `Total Amount on Check/ACH`,
                                                  required: true
                                                },
                                              ]
                                            },
                                            ...(
                                              check.split.length ? [
                                                {
                                                  wrapperClass: 'row',
                                                  className: 'col-12 form-group',
                                                  field: 'h4',
                                                  children: `Split amounts are subtracted from the Check Amount ($${check.amount || 0}). The remaining amount is applied to ${check.dus_id}. Total Split Amounts MUST be less than $${check.amount || 0}`
                                                }
                                              ] : []
                                            ),
                                            ...(check.split || []).map((r, i) => ({
                                              key: i,
                                              className: 'row',
                                              fields: [
                                                {
                                                  field: 'TextField',
                                                  wrapperClass: `col-6 form-group was-validated`,
                                                  label: `Split DUS ID ${i + 1}`,
                                                  name: `payment.checks.${c}.split.${i}.dus_id`,
                                                  type: 'text',
                                                  value: r.dus_id || '',
                                                  onChange: true,
                                                  autoComplete: `invalid ${autoComplete}`,
                                                },
                                                {
                                                  field: 'TextField',
                                                  wrapperClass: `col-6 form-group was-validated`,
                                                  label: `Split Amount ${i + 1}`,
                                                  name: `payment.checks.${c}.split.${i}.amount`,
                                                  type: 'text',
                                                  value: r.amount || '',
                                                  onChange: true,
                                                  autoComplete: `invalid ${autoComplete}`,
                                                  feedback: `Apply $${r.amount || '0'} of $${check.amount || 0} to ${r.dus_id}`
                                                },
                                              ]
                                            })),
                                            {
                                              className: 'btn btn-block btn-warning form-group',
                                              field: 'button',
                                              onClick: () => this.addSplit(c),
                                              children: 'Add Split'
                                            }
                                          ]
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-12 form-group ${check.billing.company_validated ? 'was-validated' : ''}`,
                                          label: 'Company',
                                          name: `payment.checks.${c}.billing.company`,
                                          type: 'text',
                                          value: check.billing.company || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-12 form-group ${check.billing.name_validated ? 'was-validated' : ''}`,
                                          label: 'Name*',
                                          name: `payment.checks.${c}.billing.name`,
                                          placeholder: '(John Jonah Jameson Jr)',
                                          type: 'text',
                                          value: check.billing.name || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 form-group ${check.billing.phone_validated ? 'was-validated' : ''}`,
                                          label: 'Phone Number',
                                          name: `payment.checks.${c}.billing.phone`,
                                          placeholder: '(435-753-4732)',
                                          type: 'text',
                                          inputMode: 'numeric',
                                          value: check.billing.phone,
                                          usePhoneFormat: true,
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 form-group ${check.billing.email_validated ? 'was-validated' : ''}`,
                                          className: 'form-control form-group',
                                          label: 'Email',
                                          placeholder: '(your@email.com)',
                                          name: `payment.checks.${c}.billing.email`,
                                          type: 'email',
                                          value: check.billing.email,
                                          onChange: true,
                                          useEmailFormat: true,
                                          feedback: (
                                            <span className={`${emailRegex.test(check.billing.email) ? 'd-none' : 'text-danger'}`}>
                                              Please enter a valid email
                                            </span>
                                          ),
                                        },
                                        {
                                          field: 'button',
                                          type: 'button',
                                          wrapperClass: 'col-12 form-group',
                                          className: 'btn btn-danger btn-block',
                                          children: 'No Billing Address Available',
                                          onClick: () => this.noAddress(c),
                                          disabled: !!check.billing.street_address
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 col-12 form-group ${check.billing.street_address_validated ? 'was-validated' : ''}`,
                                          label: 'Billing Street*',
                                          name: `payment.checks.${c}.billing.street_address`,
                                          placeholder: '(1755 N 400 E)',
                                          type: 'text',
                                          value: check.billing.street_address || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 col-12 form-group ${check.billing.extended_address_validated ? 'was-validated' : ''}`,
                                          label: 'Billing Street 2',
                                          placeholder: '(Ste 201)',
                                          name: `payment.checks.${c}.billing.extended_address`,
                                          type: 'text',
                                          value: check.billing.extended_address || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-4 form-group ${check.billing.locality_validated ? 'was-validated' : ''}`,
                                          label: 'Billing City*',
                                          placeholder: '(Logan)',
                                          name: `payment.checks.${c}.billing.locality`,
                                          type: 'text',
                                          value: check.billing.locality || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-4 col-6 form-group ${check.billing.locality_validated ? 'was-validated' : ''}`,
                                          label: 'Billing State*',
                                          placeholder: '(UT)',
                                          name: `payment.checks.${c}.billing.region`,
                                          type: 'text',
                                          value: check.billing.region || '',
                                          pattern: '[A-Z]{2}',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-4 col-6 form-group ${check.billing.postal_code_validated ? 'was-validated' : ''}`,
                                          label: 'Billing Zip*',
                                          name: `payment.checks.${c}.billing.postal_code`,
                                          placeholder: '(84321)',
                                          type: 'text',
                                          value: check.billing.postal_code || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true,
                                          pattern: '[0-9]{4,5}(-[0-9]{4})?'
                                        },

                                        {
                                          field: 'SelectField',
                                          onChange: true,
                                          valueKey: 'value',
                                          viewProps: {
                                            className: 'form-control',
                                            autoComplete: `invalid ${autoComplete}`,
                                            required: true,
                                          },
                                          wrapperClass: `col-md-6 col-12 form-group ${check.transaction_type_validated ? 'was-validated' : ''}`,
                                          label: 'Payment Type',
                                          name: `payment.checks.${c}.transaction_type`,
                                          options: directTypes,
                                          value: check.transaction_type || '',
                                          autoComplete: `invalid ${autoComplete}`,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 col-12 form-group ${check.gateway.transaction_type_validated ? 'was-validated' : ''}`,
                                          label: 'Transaction Type*',
                                          name: `payment.checks.${c}.gateway.transaction_type`,
                                          placeholder: '(PPD)',
                                          type: 'text',
                                          value: check.gateway.transaction_type || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 col-12 form-group ${check.date_entered_validated ? 'was-validated' : ''}`,
                                          label: 'Date Entered (YYYY-MM-DD)',
                                          name: `payment.checks.${c}.date_entered`,
                                          placeholder: '(YYYY-MM-DD)',
                                          pattern: '20(1[8-9]|20)-[0-1][0-9]-[0-3][0-9]',
                                          inputMode: 'numeric',
                                          type: 'text',
                                          value: check.date_entered || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          feedback: 'leave blank for current time',
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 col-12 form-group ${check.time_entered_validated ? 'was-validated' : ''}`,
                                          label: 'Time Entered (24 Hr or with AM/PM)',
                                          name: `payment.checks.${c}.time_entered`,
                                          placeholder: '(13:59 or 01:59 PM)',
                                          pattern: '[0-2]?[0-9]:[0-6][0-9]( [AP]M)?',
                                          inputMode: 'numeric',
                                          type: 'text',
                                          value: check.time_entered || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          feedback: 'leave blank for current time',
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 col-12 form-group ${check.gateway.bank_name_validated ? 'was-validated' : ''}`,
                                          label: 'Bank Name*',
                                          name: `payment.checks.${c}.gateway.bank_name`,
                                          placeholder: '(US Bank)',
                                          type: 'text',
                                          value: check.gateway.bank_name || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 col-12 form-group ${check.gateway.routing_number_validated ? 'was-validated' : ''}`,
                                          label: 'Routing Number*',
                                          name: `payment.checks.${c}.gateway.routing_number`,
                                          placeholder: '(111111111)',
                                          type: 'text',
                                          value: check.gateway.routing_number || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 col-12 form-group ${check.gateway.account_number_validated ? 'was-validated' : ''}`,
                                          label: 'Account Number (Last 4)*',
                                          name: `payment.checks.${c}.gateway.account_number`,
                                          placeholder: '(1234)',
                                          inputMode: 'numeric',
                                          type: 'text',
                                          value: check.gateway.account_number || '',
                                          onChange: true,
                                          autoComplete: `invalid ${autoComplete}`,
                                          required: true,
                                        },
                                        {
                                          field: 'BooleanField',
                                          topLabel: 'Send Email?',
                                          label: 'Send Receipt?',
                                          name: `payment.checks.${c}.gateway.send_email`,
                                          wrapperClass: 'col-12 form-group',
                                          checked: !!check.gateway.send_email,
                                          value: !!check.gateway.send_email,
                                          toggle: true,
                                          className: ''
                                        },
                                      ]
                                    }
                                  ]
                                })
                              )
                            ),
                            {
                              className: 'col-12 form-group',
                              fields: [
                                {
                                  field: 'button',
                                  className: 'btn btn-warning btn-lg active float-left',
                                  type: 'button',
                                  children: 'Add Item',
                                  onClick: this.addCheck
                                },
                                {
                                  field: 'button',
                                  className: 'btn btn-primary btn-lg active float-right',
                                  type: 'submit',
                                  children: [
                                    `Submit Payment(s) totaling $${parseFloat(this.state.form.payment.amount)}`
                                  ]
                                }
                              ]
                            }
                          ] : [
                            {
                              className: 'col-12 text-info text-center',
                              children: [
                                <u key='1'>
                                  Amount must be filled out before entering Details
                                </u>
                              ]
                            }
                          ]
                        )
                      ]
                    },
                  ]}
                />
                {
                  this.state.successful && this.renderSuccess()
                }
                {this.renderReceipts()}
                {this.renderErrors()}
              </DisplayOrLoading>
            </div>
          </section>
        </form>
      </DisplayOrLoading>
    )
  }
}
