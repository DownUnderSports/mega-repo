import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import { emailRegex } from 'common/js/helpers/email';

export default class PaymentForm extends Component {
  constructor(props) {
    super(props)

    const amount = (
      props.defaultAmount
      ? currencyFormat(props.defaultAmount)
      : (props.minimum ? currencyFormat(props.minimum) : '')
    )



    this.state = {
      captcha: this.props.captcha || '',
      receiptId: null,
      errors: null,
      changed: false,
      showDropInForm: false,
      form: {
        state_id: props.stateId || '',
        sport_id: props.sportId || '',
        agreed: !!this.props.agreed,
        payment: {
          anonymous: false,
          gateway_type: 'auth_net',
          amount,
          card_number: '',
          cvv: '',
          expiration_month: '',
          expiration_year: '',
          billing: {
            company: '',
            name: '',
            email: '',
            phone: '',
            country_code_alpha3: '',
            extended_address: '',
            locality: '',
            postal_code: '',
            region: '',
            street_address: '',
          },
          split: [],
          nonce: '',
          notes: '',
        },
        is_foreign: false,
      }
    }

    this.action = `${props.url || `/api/users/${props.id || ''}/payments`}`
  }

  allowNext = () => {
    const values = this.state.form.payment
    return !!(
      values.amount
      // && this.state.captcha
      // && values.billing.first_name
      // && values.billing.last_name
      && values.billing.name
      && values.billing.postal_code
      && values.billing.street_address
      && values.billing.region
    )
  }

  getNonce = (result) => {
    this.onChange(false, 'payment.nonce', result.nonce, this.onSubmit)
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

  showCardEntry = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.setState({
      showDropInForm: true
    })
  }

  onSubmit = (e) => {
    e && e.preventDefault();
    this.setState({submitting: true}, () => this.handleSubmit())

  }

  stopPropagation = (ev) => ev.stopPropagation()

  invalidAmount = (amount) => parseFloat(amount || 0, 10) < (this.props.minimum ? Math.min(parseFloat(this.props.minimum, 10), parseFloat(20, 10)) : parseFloat(1, 10))

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

      try {
        if(this.props.id) {
          const val = sessionStorage.getItem(this.props.id)
          val && (val === "1")
          && sessionStorage.setItem(this.props.id, 2)
        }
      } catch(_) {}


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
    const { captcha, /*breakPoint = 'col-md-6',*/ teamSelect, minimum } = this.props,
          is_foreign = !!this.state.form.is_foreign

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
                  form='payment'
                  fields={[
                    {
                      className: 'row',
                      fields: this.state.showDropInForm ? [
                      // fields: true ? [

                        // {
                        //   field: 'BraintreeDropIn',
                        //   wrapperClass: `col-12 form-group`,
                        //   label: 'Payment Details',
                        //   name: 'payment.amount',
                        //   amount: parseFloat(this.state.form.payment.amount),
                        //   onChange: false,
                        //   onComplete: this.getNonce,
                        //   submitMessage: `Submit Payment of $${parseFloat(this.state.form.payment.amount)}`
                        // }
                      ] : [
                        {
                          field: 'TextField',
                          wrapperClass: `col-md-6 form-group ${(captcha || this.state.form.payment.amount_validated) ? 'was-validated' : ''}`,
                          label: 'Payment Amount*',
                          name: 'payment.amount',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.payment.amount || '',
                          useCurrencyFormat: true,
                          onChange: true,
                          autoComplete: 'off',
                          placeholder: '(300.00)',
                          feedback: `Total Amount to Charge Card${minimum === 300 ? ' (All Travelers must meet the $300 deposit before they will receive their Travel Shirt/Fundraising Packet)' : ''}`,
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
                                  wrapperClass: `col-6 form-group ${(captcha || this.state.form.state_id_validated) ? 'was-validated' : ''}`,
                                  label: 'Team State',
                                  name: 'state_id',
                                  value: this.state.form.state_id || '',
                                  onChange: true,
                                  autoCompleteKey: 'label',
                                  valueKey: 'value',
                                  viewProps: {
                                    className: 'form-control',
                                    autoComplete: 'off',
                                    required: false,
                                  },
                                },
                                {
                                  field: 'SportSelectField',
                                  wrapperClass: `col-6 form-group ${(captcha || this.state.form.sport_id_validated) ? 'was-validated' : ''}`,
                                  label: 'Team Sport',
                                  name: 'sport_id',
                                  value: this.state.form.sport_id || '',
                                  onChange: true,
                                  autoCompleteKey: 'label',
                                  valueKey: 'value',
                                  viewProps: {
                                    className: 'form-control',
                                    autoComplete: 'off',
                                    required: false,
                                  },
                                },
                              ]
                            }
                          ] : []
                        ),
                        ...(
                          captcha ? [
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
                                      autoComplete: 'off',
                                    },
                                    {
                                      field: 'TextField',
                                      wrapperClass: `col-6 form-group was-validated`,
                                      label: `Split Amount ${i + 1}`,
                                      name: `payment.split.${i}.amount`,
                                      type: 'text',
                                      value: r.amount || '',
                                      onChange: true,
                                      autoComplete: 'off',
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
                            }
                          ] : (
                            minimum ? [
                              {
                                field: 'TextAreaField',
                                label: 'Notes',
                                name: 'payment.notes',
                                wrapperClass: 'col-12 form-group',
                                value: this.state.form.payment.notes || '',
                                className: 'form-control',
                                onChange: true
                              },
                              {
                                className: 'col-12 form-group',
                                children: [
                                  <small key='0'>
                                    <i>
                                      If you want to apply a portion of this payment toward additional people,
                                      please list their full name here and how much of your payment
                                      you would like to be applied to them (e.g. George O&apos;Scanlon $300.00). <strong>Please use a new line for each person</strong>
                                    </i>
                                  </small>,
                                  <hr key='1'/>
                                ]
                              },
                            ] : []
                          )
                        ),
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.payment.billing.company_validated) ? 'was-validated' : ''}`,
                          label: 'Company',
                          name: 'payment.billing.company',
                          type: 'text',
                          value: this.state.form.payment.billing.company || '',
                          onChange: true,
                          autoComplete: 'billing company',
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.payment.billing.name_validated) ? 'was-validated' : ''}`,
                          label: 'Name (As Shown on Card)*',
                          name: 'payment.billing.name',
                          placeholder: '(John Jonah Jameson Jr)',
                          type: 'text',
                          value: this.state.form.payment.billing.name || '',
                          onChange: true,
                          autoComplete: 'cc-name',
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-6 form-group ${(captcha || this.state.form.payment.billing.phone_validated) ? 'was-validated' : ''}`,
                          label: 'Phone Number*',
                          name: 'payment.billing.phone',
                          placeholder: '(435-753-4732)',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.payment.billing.phone,
                          usePhoneFormat: true,
                          onChange: true,
                          required: true,
                          autoComplete: 'tel',
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-6 form-group ${(captcha || this.state.form.payment.billing.email_validated) ? 'was-validated' : ''}`,
                          className: 'form-control form-group',
                          label: 'Email*',
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
                          required: true,
                        },
                        // {
                        //   field: 'TextField',
                        //   wrapperClass: `col-4 form-group ${(captcha || this.state.form.payment.billing.first_name_validated) ? 'was-validated' : ''}`,
                        //   label: 'First Name',
                        //   name: 'payment.billing.first_name',
                        //   type: 'text',
                        //   value: this.state.form.payment.billing.first_name || '',
                        //   onChange: true,
                        //   autoComplete: 'cc-given-name',
                        //   required: true
                        // },
                        // {
                        //   field: 'TextField',
                        //   wrapperClass: `col-4 form-group ${(captcha || this.state.form.payment.billing.middle_name_validated) ? 'was-validated' : ''}`,
                        //   label: 'Middle Name(s)',
                        //   name: 'payment.billing.middle_name',
                        //   type: 'text',
                        //   value: this.state.form.payment.billing.first_name || '',
                        //   onChange: true,
                        //   autoComplete: 'cc-additional-name',
                        // },
                        // {
                        //   field: 'TextField',
                        //   wrapperClass: `col-4 form-group ${(captcha || this.state.form.payment.billing.last_name_validated) ? 'was-validated' : ''}`,
                        //   label: 'Last Name',
                        //   name: 'payment.billing.last_name',
                        //   type: 'text',
                        //   value: this.state.form.payment.billing.last_name || '',
                        //   onChange: true,
                        //   autoComplete: 'cc-family-name',
                        //   required: true
                        // },
                        {
                          field: 'InlineRadioField',
                          wrapperClass: `col-12 ${(captcha || this.state.form.payment.billing.is_foreign_validated) ? 'was-validated' : ''}`,
                          className:'',
                          label:'Address Type',
                          name: 'is_foreign',
                          options:[
                            {value: false, label: 'US Address'},
                            {value: true, label: 'Foreign Address'},
                          ],
                          value: !!is_foreign,
                          onChange: true,
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.payment.billing.street_address_validated) ? 'was-validated' : ''}`,
                          label: 'Billing Street*',
                          name: 'payment.billing.street_address',
                          placeholder: '(1755 N 400 E)',
                          type: 'text',
                          value: this.state.form.payment.billing.street_address || '',
                          onChange: true,
                          autoComplete: 'billing address-line1',
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.payment.billing.extended_address_validated) ? 'was-validated' : ''}`,
                          label: 'Billing Street 2',
                          placeholder: '(Ste 201)',
                          name: 'payment.billing.extended_address',
                          type: 'text',
                          value: this.state.form.payment.billing.extended_address || '',
                          onChange: true,
                          autoComplete: 'billing address-line2',
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.payment.billing.locality_validated) ? 'was-validated' : ''}`,
                          label: `Billing City${is_foreign ? '' : '*'}`,
                          placeholder: '(Logan)',
                          name: 'payment.billing.locality',
                          type: 'text',
                          value: this.state.form.payment.billing.locality || '',
                          onChange: true,
                          autoComplete: 'billing address-level2',
                          required: !is_foreign
                        },
                        (
                          is_foreign ? (
                            {
                              field: 'TextField',
                              wrapperClass: `col-6 form-group ${(captcha || this.state.form.payment.billing.region_validated) ? 'was-validated' : ''}`,
                              label: 'Billing Province/Parish*',
                              name: 'payment.billing.region',
                              placeholder: "(Smith's Parish)",
                              type: 'text',
                              value: this.state.form.payment.billing.region || '',
                              onChange: true,
                              autoComplete: 'billing address-level1',
                              required: true,
                            }
                          ) : (
                            {
                              field: 'StateSelectField',
                              wrapperClass: `col-6 form-group ${(captcha || this.state.form.payment.billing.region_validated) ? 'was-validated' : ''}`,
                              label: 'Billing State*',
                              name: 'payment.billing.region',
                              value: this.state.form.payment.billing.region || '',
                              onChange: true,
                              autoCompleteKey: 'abbr',
                              valueKey: 'abbr',
                              viewProps: {
                                placeholder: '(UT)',
                                pattern: '[A-Z]{2}',
                                className: 'form-control',
                                autoComplete: 'billing address-level1',
                                required: true,
                              },
                            }
                          )
                        ),
                        {
                          field: 'TextField',
                          wrapperClass: `${is_foreign ? 'col-3' : 'col-6'} form-group ${(captcha || this.state.form.payment.billing.postal_code_validated) ? 'was-validated' : ''}`,
                          label: `Billing ${is_foreign ? 'Postal Code' : 'Zip'}*`,
                          name: 'payment.billing.postal_code',
                          placeholder: is_foreign ? '(FL 07)' : '(84321)',
                          type: 'text',
                          value: this.state.form.payment.billing.postal_code || '',
                          onChange: true,
                          autoComplete: 'billing postal-code',
                          required: true,
                          pattern: is_foreign ? null : '[0-9]{4,5}(-[0-9]{4})?'
                        },
                        ...(is_foreign ? [
                          {
                            field: 'CountrySelectField',
                            wrapperClass: `col-6 form-group ${(captcha || this.state.form.payment.billing.country_code_alpha3_validated) ? 'was-validated' : ''}`,
                            label: 'Billing Country*',
                            name: 'payment.billing.country_code_alpha3',
                            value: this.state.form.payment.billing.country_code_alpha3 || '',
                            onChange: true,
                            autoCompleteKey: 'code',
                            valueKey: 'code',
                            viewProps: {
                              placeholder: '(USA)',
                              pattern: '[A-Z]{3}',
                              className: 'form-control',
                              autoComplete: 'billing country',
                              required: true,
                            },
                          },
                        ] : []),
                        {
                          field: 'BooleanField',
                          topLabel: 'Anonymous Donor?',
                          label: `Will${this.state.form.payment.anonymous ? '' : ' not'} be anonymous`,
                          name: 'payment.anonymous',
                          wrapperClass: `col-12 form-group`,
                          checked: !!this.state.form.payment.anonymous,
                          value: !!this.state.form.payment.anonymous,
                          toggle: true,
                          className: ''
                        },
                        {
                          className: 'col-12',
                          fields: [
                            {
                              className: 'row',
                              fields: [
                                // ...(captcha ? [] : [
                                //   {
                                //     field: 'Recaptcha',
                                //     // className: 'g-recaptcha d-flex justify-content-end',
                                //     wrapperClass: `col form-group`,
                                //     sitekey: '6LfLC3MUAAAAAKlVoWnJU39qEjwdqenGGkvbV7Hq',
                                //     render: 'explicit',
                                //     onVerify: (val) => this.setState({
                                //       captcha: val
                                //     }),
                                //     id: `${this.props.id}-google-verify`
                                //   },
                                // ]),
                                this.allowNext()
                                  ? {
                                      field: 'CreditCardField',
                                      wrapperClass: `${/*breakPoint*/ 'col'} form-group ${(captcha || this.state.form.payment.card_number_validated) ? 'was-validated' : ''}`,
                                      onChange: false,
                                      onCardChange: (val) => {
                                        this.onChange(false, 'payment.card_number', val)
                                      },
                                      onCvvChange: (val) => {
                                        this.onChange(false, 'payment.cvv', val)
                                      },
                                      onMonthChange: (val) => {
                                        this.onChange(false, 'payment.expiration_month', val)
                                      },
                                      onYearChange: (val) => {
                                        this.onChange(false, 'payment.expiration_year', val)
                                      },
                                      cardProps: {
                                        name: 'payment.card_number',
                                        placeholder: '···· ···· ···· ····',
                                        required: true,
                                      },
                                      cvvProps: {
                                        name: 'payment.cvv',
                                        placeholder: '...',
                                        required: true
                                      },
                                      monthProps: {
                                        name: 'payment.expiration_month',
                                        placeholder: '..',
                                        required: true
                                      },
                                      yearProps: {
                                        name: 'payment.expiration_year',
                                        placeholder: '..',
                                        required: true
                                      }
                                    }
                                  : { className: 'col' },
                                {
                                  field: 'SiteSeal',
                                  wrapperClass: `col-auto form-group`,
                                  className: 'd-block',
                                }
                              ]
                            }
                          ]
                        },
                        ...(
                            this.allowNext() ? [
                              {
                                field: 'input',
                                type: 'hidden',
                                name: 'payment.gateway_type',
                                value: this.state.form.payment.gateway_type,
                              },
                              {
                                field: 'Link',
                                to: 'https://www.downundersports.com/terms',
                                target: '_terms',
                                wrapperClass: 'col-12 text-center form-group',
                                className: 'text-info',
                                children: [
                                  <u key='1'>
                                    ALL participants and travelers are subject to the Down Under Sports Program Terms and Conditions
                                  </u>
                                ]
                              },
                              {
                                field: 'BooleanField',
                                skipTopLabel: true,
                                label: <>
                                  <span key="text">
                                    Check this box to signify you have read and agree to the
                                  </span> <Link onClick={this.stopPropagation} key="link" to="/refunds" target="refund_terms" rel="noopener noreferrer">
                                    Down Under Sports Refund Policy
                                  </Link>
                                </>,
                                name: 'agreed',
                                wrapperClass: `col-12 form-group`,
                                checked: !!this.state.form.agreed,
                                value: !!this.state.form.agreed,
                                toggle: true,
                                className: ''
                              },
                              {
                                field: 'button',
                                wrapperClass: 'col-12 form-group',
                                className: 'btn btn-primary btn-lg active float-right',
                                type: 'submit',
                                disabled: !this.state.form.agreed,
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
