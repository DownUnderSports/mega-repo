import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import { emailRegex } from 'common/js/helpers/email';


const achTypes = [
        {value: 'ach', label: 'ACH Payment'},
        {value: 'check', label: 'Check Payment'},
        {value: 'card', label: 'Card Payment'},
      ],
      checkHeaders = [
        "Transaction ID",
        "Authorization Code",
        "Date/Time Entered",
        "Settlement Date",
        "Amount",
        "Status",
        "Payment Type",
        "Reason Description",
        "Can Void Until",
        "Transaction Type",
        "Bank Name",
        "Routing Number",
        "Account Type",
        "Account Number",
        "Payment Description",
        "Invoice #",
        "PO #",
        "Customer ID ",
        "Name",
        "Company",
        "Billing Address",
        "Shipping Address",
      ]


export default class CheckPaymentForm extends Component {
  constructor(props) {
    super(props)

    this.state = {
      receiptId: null,
      errors: null,
      changed: false,
      form: {
        state_id: props.stateId || '',
        sport_id: props.sportId || '',
        send_email: '',
        payment: {
          transaction_id: '',
          transaction_type: '',
          amount: '',
          date_entered: '',
          time_entered: '',
          remit_number: '',
          billing: {
            customer_id: '',
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
            transaction_type: '',
            account_number: '',
            account_type: '',
            bank_name: '',
            routing_number: '',
            expiration: '',
            deposit_number: '',
            deposited_items: '',
            check_number: '',
          },
          settlement: {
            settlement_date: '',
            voidable_date: '',
            voided_date: '',
          },
          processor: {
            message: ''
          },
          split: [],
          notes: '',
        },
      }
    }

    this.action = `${props.url || `/api/users/${props.id || ''}/payments/ach`}`
  }

  allowNext = () => {
    const values = this.state.form.payment
    return !!(
      values.amount
      && values.billing.name
      && values.billing.postal_code
      && values.billing.street_address
      && values.billing.locality
    )
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
      json = await result.json()

      return this.setState({
        receiptId: json.id
      }, () => (
        (this.props.onSuccess && this.props.onSuccess(json.id)) ||
        this.props.history.push(`/payments/${json.id}`)
      ))
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

  addSplit = () => {
    let form = Objected.deepClone(this.state.form),
        split = form.payment.split;

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

  parseCheck = (lines) => {
    const form = Objected.deepClone(this.state.form)

    let lastLine = null

    form.payment.transaction_type = 'check'
    form.payment.gateway.transaction_type = 'direct'

    for(let i = 0; i < lines.length; i++) {
      const line = lines[i]
      if(lastLine === 'depositInfo') {
        lastLine = null
        const row = this.splitLine(line)
        form.payment.amount = currencyFormat(row[2])
        form.payment.gateway.deposit_number = row[0]
        form.payment.gateway.deposited_items = row[1]
      } else if(lastLine === 'itemInfo') {
        lastLine = 'itemInfoCredit'
      } else if(lastLine === 'itemInfoCredit') {
        lastLine = null
        const row = this.splitLine(line)
        form.payment.transaction_id = `CHECK${(row[2] || '').rjust('0', 8)}`
        form.payment.gateway.routing_number = row[3]
        form.payment.gateway.account_number = row[4].slice(row[4].length - 4)
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

  parseZionsPaste = (ev) => {
    const rawZions = ev.target.value.replace(/\n\n/g, "\n"),
        pmtInfo = rawZions.match(/payment\s+info.*?\n\s*(trans[\s\S]*)\norder\s+info[\s\S]*?\ncustomer\s+info.*?\n(customer\s+id[\s\S]*)\s+shipping/i) || [],
        parsed = {}

    if(!pmtInfo.length) return this.parseCheck(rawZions.split(/\n/))

    for(let i = 1; i < (pmtInfo || []).length; i++) {
      let str = pmtInfo[i].split(/\n/),
          b = 0

      const billingLines = [],
            streetReg = /billing\s+address/i

      if(str.some(v => streetReg.test(v))) {
        do {
          let line = str.pop()
          switch (b) {
            case 0:
              line = `billing_state: ${line}`
              break;
            case 1:
              if(!(streetReg.test(line))) {
                line = `extended_address: ${line}`
              }
              break;
            default:
              break;
          }
          billingLines.unshift(line)
          b++
        } while(!(streetReg.test(billingLines[0])) && str.length)

        str.push(...billingLines)
      }

      for(let s = 0; s < str.length; s++){
        let row = str[s],
            fields = row.split(/\t\s*\t/);

        for(let f = 0; f < fields.length; f++) {
          let field = fields[f]
          if(/:[^:]+:/.test(field)) {
            const reg = new RegExp(`((?:${checkHeaders.join("|")}\\s*):(?!${checkHeaders.join("|")})+)+`, 'g'),
                  arr = field.split(reg)
            if(arr.length) {
              if(!arr[0]) arr.shift()
              for(let c = 0; c < arr.length; c++) {
                let col = arr[c].replace(/\s*:/, '').toLowerCase().trim().replace(/[^a-z]+/g, '_'),
                val = `${arr[++c] || ''}`.trim()
                if(col && val) parsed[col] = val
              }
            }
          } else {
            field = field.split(/:\s+/)
            parsed[field[0].trim().toLowerCase().replace(/[^a-z]+/g, '_')] = `${field[1] || ''}`.trim()
          }
        }
      }
    }

    let form = Objected.deepClone(this.state.form)

    if(parsed.amount) form.payment.amount = currencyFormat(parsed.amount)
    if(parsed.customer_id) form.payment.billing.customer_id = parsed.customer_id
    if(parsed.company) form.payment.billing.company = parsed.company
    if(parsed.name) {
      try {
        let nm = parsed.name.split(/,\s+/)
        form.payment.billing.name = `${nm[1]} ${nm[0]}`
      } catch(e) {
        form.payment.billing.name = parsed.name
      }
    }
    if(parsed.billing_address) {
      form.payment.billing.street_address = `${parsed.billing_address || ''}`.trim()
    }
    if(parsed.extended_address) {
      form.payment.billing.extended_address = `${parsed.extended_address || ''}`.trim()
    }
    if(parsed.billing_state) {
      try {
        parsed.billing_state = parsed.billing_state.split(',')
        form.payment.billing.locality = `${parsed.billing_state[0]}`.trim()
        parsed.billing_state = `${parsed.billing_state[1]}`.trim().split(/\s+/)
        form.payment.billing.region = `${parsed.billing_state[0]}`.trim()
        form.payment.billing.postal_code = `${parsed.billing_state[1]}`.trim()
      } catch (e) {
        form.payment.billing.locality = ''
        form.payment.billing.region = ''
        form.payment.billing.postal_code = ''
      }
    }
    if(parsed.can_void_until) {
      form.payment.settlement.voidable_date = this.americanToUniversal(parsed.can_void_until)
    }
    let isCard = false
    if(parsed.payment_type) {
      if(/^ACH/.test(parsed.payment_type)) {
        form.payment.transaction_type = 'ach'
      } else if((/^check/i).test(parsed.payment_type)) {
        form.payment.transaction_type = 'check'
      } else {
        isCard = true
        form.payment.transaction_type = 'card'
      }
    }
    if(form.payment.transaction_type === 'card') {
      if(parsed.credit_card_account) {
        form.payment.gateway.account_number = parsed.credit_card_account.replace(/[^0-9]/g, '')
      }
      if(parsed.credit_card_type) {
        form.payment.gateway.account_type = parsed.credit_card_type
      }
      if(parsed.expiration_date) {
        let d = parsed.expiration_date.split(/[^0-9]/)
        form.payment.gateway.expiration = `${d[0].rjust(2, '0')}/${d[1].replace(/^20/, '')}`
      }
    } else {
      if(parsed.account_number) {
        form.payment.gateway.account_number = parsed.account_number.replace(/[^0-9]/g, '')
      }
      if(parsed.bank_name) form.payment.gateway.bank_name = parsed.bank_name
      if(parsed.routing_number) form.payment.gateway.routing_number = parsed.routing_number
    }
    if(parsed.date_time_entered) {
      parsed.date_time_entered = parsed.date_time_entered.split(/\s+/)
      form.payment.date_entered = this.americanToUniversal(parsed.date_time_entered[0])
      parsed.time = parsed.date_time_entered[1].match(/(\d+):(\d+)([A-Z]+)/) || []
      form.payment.time_entered = `${(parsed.time[1] || '').rjust(2, '0')}:${(parsed.time[2] || '').rjust(2, '0')} ${parsed.time[3] || ''}`.trim()
      if(parsed.payment_type) {
        form.payment.remit_number = `${form.payment.date_entered}-${isCard ? 'CC' : form.payment.transaction_type.toUpperCase()}`
      }
    }
    if(parsed.settlement_date) {
      form.payment.settlement.settlement_date = this.americanToUniversal(parsed.settlement_date)
    }
    if(parsed.status) form.payment.status = parsed.status
    if(parsed.reason_description) form.payment.processor.message = parsed.reason_description
    if(parsed.transaction_id) form.payment.transaction_id = parsed.transaction_id
    if(parsed.transaction_type) form.payment.gateway.transaction_type = parsed.transaction_type

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

  render(){
    const { teamSelect } = this.props,
          autoComplete = new Date()

    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        <form
          action={this.action}
          method='post'
          className='payment-form mb-3'
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
                          changeOverride: this.parseZionsPaste,
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
                          teamSelect ? [
                            {
                              className: 'row',
                              wrapperClass:'col',
                              fields: [
                                {
                                  field: 'StateSelectField',
                                  wrapperClass: `col-6 form-group ${this.state.form.state_id_validated ? 'was-validated' : ''}`,
                                  label: 'Team State',
                                  name: 'state_id',
                                  value: this.state.form.state_id || '',
                                  onChange: true,
                                  autoCompleteKey: 'label',
                                  valueKey: 'value',
                                  viewProps: {
                                    className: 'form-control',
                                    autoComplete: `invalid ${autoComplete}`,
                                    required: false,
                                  },
                                },
                                {
                                  field: 'SportSelectField',
                                  wrapperClass: `col-6 form-group ${this.state.form.sport_id_validated ? 'was-validated' : ''}`,
                                  label: 'Team Sport',
                                  name: 'sport_id',
                                  value: this.state.form.sport_id || '',
                                  onChange: true,
                                  autoCompleteKey: 'label',
                                  valueKey: 'value',
                                  viewProps: {
                                    className: 'form-control',
                                    autoComplete: `invalid ${autoComplete}`,
                                    required: false,
                                  },
                                },
                              ]
                            }
                          ] : []
                        ),
                        {
                          className: 'col-12',
                          fields: [
                            ...(
                              this.state.form.payment.split.length ? [
                                {
                                  wrapperClass: 'row',
                                  className: 'col-12 form-group',
                                  field: 'h4',
                                  children: `Split amounts are subtracted from the Payment Amount ($${this.state.form.payment.amount || 0}). The remaining amount is applied to ${this.props.id}. Total Split Amounts MUST be less than $${this.state.form.payment.amount || 0}`
                                }
                              ] : []
                            ),
                            ...(this.state.form.payment.split || []).map((r, i) => ({
                              key: i,
                              className: 'row',
                              fields: [
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-6 form-group was-validated`,
                                  label: `Split DUS ID ${i + 1}`,
                                  name: `payment.split.${i}.dus_id`,
                                  type: 'text',
                                  value: r.dus_id || '',
                                  onChange: true,
                                  autoComplete: `invalid ${autoComplete}`,
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-6 form-group was-validated`,
                                  label: `Split Amount ${i + 1}`,
                                  name: `payment.split.${i}.amount`,
                                  type: 'text',
                                  value: r.amount || '',
                                  onChange: true,
                                  autoComplete: `invalid ${autoComplete}`,
                                  feedback: `Apply $${r.amount || '0'} of $${this.state.form.payment.amount || 0} to ${r.dus_id}`
                                },
                              ]
                            })),
                            {
                              className: 'btn btn-block btn-warning form-group',
                              field: 'button',
                              onClick: this.addSplit,
                              children: 'Add Split'
                            }
                          ]
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${this.state.form.payment.billing.customer_id_validated ? 'was-validated' : ''}`,
                          label: 'Customer ID',
                          name: 'payment.billing.customer_id',
                          type: 'text',
                          inputMode: 'numeric',
                          pattern: '[0-9]+',
                          value: this.state.form.payment.billing.customer_id || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${this.state.form.payment.billing.company_validated ? 'was-validated' : ''}`,
                          label: 'Company',
                          name: 'payment.billing.company',
                          type: 'text',
                          value: this.state.form.payment.billing.company || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${this.state.form.payment.billing.name_validated ? 'was-validated' : ''}`,
                          label: 'Name*',
                          name: 'payment.billing.name',
                          placeholder: '(John Jonah Jameson Jr)',
                          type: 'text',
                          value: this.state.form.payment.billing.name || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-6 form-group ${this.state.form.payment.billing.phone_validated ? 'was-validated' : ''}`,
                          label: 'Phone Number',
                          name: 'payment.billing.phone',
                          placeholder: '(435-753-4732)',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.payment.billing.phone,
                          usePhoneFormat: true,
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-6 form-group ${this.state.form.payment.billing.email_validated ? 'was-validated' : ''}`,
                          className: 'form-control form-group',
                          label: 'Email',
                          placeholder: '(your@email.com)',
                          name: `payment.billing.email`,
                          type: 'email',
                          value: this.state.form.payment.billing.email,
                          onChange: true,
                          useEmailFormat: true,
                          feedback: (
                            <span className={`${emailRegex.test(this.state.form.payment.billing.email) ? 'd-none' : 'text-danger'}`}>
                              Please enter a valid email
                            </span>
                          ),
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${this.state.form.payment.billing.street_address_validated ? 'was-validated' : ''}`,
                          label: 'Billing Street*',
                          name: 'payment.billing.street_address',
                          placeholder: '(1755 N 400 E)',
                          type: 'text',
                          value: this.state.form.payment.billing.street_address || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${this.state.form.payment.billing.extended_address_validated ? 'was-validated' : ''}`,
                          label: 'Billing Street 2',
                          placeholder: '(Ste 201)',
                          name: 'payment.billing.extended_address',
                          type: 'text',
                          value: this.state.form.payment.billing.extended_address || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${this.state.form.payment.billing.locality_validated ? 'was-validated' : ''}`,
                          label: 'Billing City*',
                          placeholder: '(Logan)',
                          name: 'payment.billing.locality',
                          type: 'text',
                          value: this.state.form.payment.billing.locality || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-6 form-group ${this.state.form.payment.billing.locality_validated ? 'was-validated' : ''}`,
                          label: 'Billing State*',
                          placeholder: '(UT)',
                          name: 'payment.billing.region',
                          type: 'text',
                          value: this.state.form.payment.billing.region || '',
                          pattern: '[A-Z]{2}',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-6 form-group ${this.state.form.payment.billing.postal_code_validated ? 'was-validated' : ''}`,
                          label: 'Billing Zip*',
                          name: 'payment.billing.postal_code',
                          placeholder: '(84321)',
                          type: 'text',
                          value: this.state.form.payment.billing.postal_code || '',
                          onChange: true,
                          autoComplete: `invalid ${autoComplete}`,
                          required: true,
                          pattern: '[0-9]{4,5}(-[0-9]{4})?'
                        },
                        ...(
                            this.allowNext() ? [
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.transaction_id_validated ? 'was-validated' : ''}`,
                                label: 'Transaction ID*',
                                name: 'payment.transaction_id',
                                placeholder: '(123456789)',
                                pattern: '(CHECK)?[0-9]+',
                                inputMode: 'numeric',
                                type: 'text',
                                value: this.state.form.payment.transaction_id || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                                required: true,
                              },
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.date_entered_validated ? 'was-validated' : ''}`,
                                label: 'Date Entered (YYYY-MM-DD)',
                                name: 'payment.date_entered',
                                placeholder: '(YYYY-MM-DD)',
                                pattern: '20(1[8-9]|20)-[0-1][0-9]-[0-3][0-9]',
                                inputMode: 'numeric',
                                type: 'text',
                                value: this.state.form.payment.date_entered || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                                feedback: 'leave blank for current time',
                              },
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.time_entered_validated ? 'was-validated' : ''}`,
                                label: 'Time Entered (24 Hr or with AM/PM)',
                                name: 'payment.time_entered',
                                placeholder: '(13:59 or 01:59 PM)',
                                pattern: '[0-2]?[0-9]:[0-6][0-9]( [AP]M)?',
                                inputMode: 'numeric',
                                type: 'text',
                                value: this.state.form.payment.time_entered || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                                feedback: 'leave blank for current time',
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
                                wrapperClass: `col-12 form-group ${this.state.form.payment.transaction_type_validated ? 'was-validated' : ''}`,
                                label: 'Payment Type',
                                name: 'payment.transaction_type',
                                options: achTypes,
                                value: this.state.form.payment.transaction_type || '',
                                autoComplete: `invalid ${autoComplete}`,
                              },
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.settlement.voidable_date_validated ? 'was-validated' : ''}`,
                                label: 'Can Void Until (YYYY-MM-DD)',
                                name: 'payment.settlement.voidable_date',
                                placeholder: '(YYYY-MM-DD)',
                                pattern: '20(1[8-9]|2[01])-[0-1][0-9]-[0-3][0-9]',
                                inputMode: 'numeric',
                                type: 'text',
                                value: this.state.form.payment.settlement.voidable_date || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                              },
                              (
                                this.state.form.payment.transaction_type === 'card' ? {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.payment.gateway.account_type_validated ? 'was-validated' : ''}`,
                                  label: 'Credit Card Type*',
                                  name: 'payment.gateway.account_type',
                                  placeholder: '(Checking)',
                                  type: 'text',
                                  value: this.state.form.payment.gateway.account_type || '',
                                  onChange: true,
                                  autoComplete: `invalid ${autoComplete}`,
                                  required: true,
                                } : {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.payment.gateway.bank_name_validated ? 'was-validated' : ''}`,
                                  label: 'Bank Name*',
                                  name: 'payment.gateway.bank_name',
                                  placeholder: '(US Bank)',
                                  type: 'text',
                                  value: this.state.form.payment.gateway.bank_name || '',
                                  onChange: true,
                                  autoComplete: `invalid ${autoComplete}`,
                                  required: true,
                                }
                              ),
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.settlement.settlement_date_validated ? 'was-validated' : ''}`,
                                label: 'Estimated Settlement Date (YYYY-MM-DD)',
                                name: 'payment.settlement.settlement_date',
                                placeholder: '(YYYY-MM-DD)',
                                pattern: '20(1[8-9]|20)-[0-1][0-9]-[0-3][0-9]',
                                inputMode: 'numeric',
                                type: 'text',
                                value: this.state.form.payment.settlement.settlement_date || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                              },
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.status_validated ? 'was-validated' : ''}`,
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
                                wrapperClass: `col-12 form-group ${this.state.form.payment.processor.message_validated ? 'was-validated' : ''}`,
                                label: 'Reason Description',
                                name: 'payment.processor.message',
                                placeholder: '(Approved)',
                                type: 'text',
                                value: this.state.form.payment.processor.message || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                              },
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.gateway.transaction_type_validated ? 'was-validated' : ''}`,
                                label: 'Transaction Type*',
                                name: 'payment.gateway.transaction_type',
                                placeholder: '(PPD)',
                                type: 'text',
                                value: this.state.form.payment.gateway.transaction_type || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                                required: true,
                              },
                              (
                                this.state.form.payment.transaction_type === 'card' ? {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.payment.gateway.expiration_validated ? 'was-validated' : ''}`,
                                  label: 'Expiration Date*',
                                  name: 'payment.gateway.expiration',
                                  placeholder: '(03/21)',
                                  pattern: '[0-9]{2}\\/[0-9]{2}([0-9]{2})?',
                                  type: 'text',
                                  value: this.state.form.payment.gateway.expiration || '',
                                  onChange: true,
                                  autoComplete: `invalid ${autoComplete}`,
                                  required: true,
                                } : {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.payment.gateway.routing_number_validated ? 'was-validated' : ''}`,
                                  label: 'Routing Number*',
                                  name: 'payment.gateway.routing_number',
                                  placeholder: '(111111111)',
                                  type: 'text',
                                  value: this.state.form.payment.gateway.routing_number || '',
                                  onChange: true,
                                  autoComplete: `invalid ${autoComplete}`,
                                  required: true,
                                }
                              ),
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.gateway.account_number_validated ? 'was-validated' : ''}`,
                                label: 'Account Number (Last 4)*',
                                name: 'payment.gateway.account_number',
                                placeholder: '(1234)',
                                inputMode: 'numeric',
                                type: 'text',
                                value: this.state.form.payment.gateway.account_number || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                                required: true,
                              },
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.payment.remit_number_validated ? 'was-validated' : ''}`,
                                label: 'Remit Number',
                                name: 'payment.remit_number',
                                placeholder: '(2018-10-31-ACH)',
                                type: 'text',
                                value: this.state.form.payment.remit_number || '',
                                onChange: true,
                                autoComplete: `invalid ${autoComplete}`,
                              },
                              {
                                field: 'BooleanField',
                                topLabel: 'Send Email?',
                                label: 'Send Receipt?',
                                name: 'send_email',
                                wrapperClass: 'col-12 form-group',
                                checked: !!this.state.form.send_email,
                                value: !!this.state.form.send_email,
                                toggle: true,
                                className: ''
                              },
                              {
                                field: 'button',
                                wrapperClass: 'col-12 form-group',
                                className: 'btn btn-primary btn-lg active float-right',
                                type: 'submit',
                                children: [
                                  `Submit Payment of $${parseFloat(this.state.form.payment.amount)}`
                                ]
                              }
                          ] : [
                            {
                              className: 'col-12 text-info text-center',
                              children: [
                                <u key='1'>
                                  ALL required fields(*) must be filled out before entering Card Info
                                </u>
                              ]
                            }
                          ]
                        )
                        // ...(
                        //     this.allowNext() ? [
                        //       {
                        //         field: 'button',
                        //         wrapperClass: 'col-12',
                        //         className: 'btn btn-block btn-secondary',
                        //         children: 'Next',
                        //         onClick: this.showCardEntry
                        //       }
                        //   ] : []
                        // )
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
