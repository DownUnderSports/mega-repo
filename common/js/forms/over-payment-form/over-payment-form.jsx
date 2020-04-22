import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
//import authFetch from 'common/js/helpers/auth-fetch'
import { emailRegex } from 'common/js/helpers/email';

export default class OverPaymentForm extends Component {
  constructor(props) {
    super(props)

    this.state = {
      captcha: this.props.captcha || '',
      receiptId: null,
      errors: null,
      changed: false,
      showDropInForm: false,
      form: {
        refund: {
          routing_number: '',
          account_number: '',
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
        },
        is_foreign: false,
      }
    }

    this.action = `${props.url || `/api/users/${props.id || ''}/refunds`}`
  }

  allowNext = () => {
    const values = this.state.form.refund
    return !!(
      values.billing.name
      && values.billing.postal_code
      && values.billing.street_address
      && values.billing.region
      // && this.state.captcha
      // && values.billing.first_name
      // && values.billing.last_name
    )
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter

    return onFormChange(this, k, v, !(/\.?routing/.test(k) && this.invalidRouting(v)), cb)
  }

  invalidRouting(value) {
    console.log(value)
    const splitUp = String(value || '')
                    .replace(/[^0-9]/g, '')
                    .split('')
                    .map(v => Number(v || 0));

    console.log(splitUp)
    if(splitUp.length !== 9) return true;

    let n = 0;

    for (let i = 0; i < 3; i++) {
      const k = i * 3;

      n += (splitUp[k] * 3)
        +  (splitUp[k + 1] * 7)
        +  (splitUp[k + 2]);
    }

    console.log(n, (n % 10 !== 0))


    return !n || (n % 10 !== 0)
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

  handleSubmit = async () => {
    if(!this.state.changed) return this.props.onSuccess && this.props.onSuccess(this.state.receiptId)
    try {
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
        submitted: json.message === 'ok',
        submitting: false
      }, () => (
        this.props.onSuccess && setTimeout(this.props.onSuccess, 2000)
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
    const { captcha } = this.props,
          is_foreign = !!this.state.form.is_foreign

    if(this.state.submitted) {
      return <section>
        <header>
          <h3 className="mt-3 alert alert-success" role="alert">
            Request Successfully Submitted!
          </h3>
        </header>
        {
          this.props.onSuccess && (
            <p>
              You will be redirected shortly...
            </p>
          )
        }
      </section>
    }

    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox className="page-loader" />
        }
      >
        <form
          action={this.action}
          method='post'
          className='refund-form mb-3'
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
                  form='refund'
                  fields={[
                    {
                      className: 'row',
                      fields: [
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.refund.billing.name_validated) ? 'was-validated' : ''}`,
                          label: 'Name (As Shown on Bank Statement)*',
                          name: 'refund.billing.name',
                          placeholder: '(John Jonah Jameson Jr)',
                          type: 'text',
                          value: this.state.form.refund.billing.name || '',
                          onChange: true,
                          autoComplete: 'cc-name',
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-6 form-group ${(captcha || this.state.form.refund.billing.phone_validated) ? 'was-validated' : ''}`,
                          label: 'Phone Number*',
                          name: 'refund.billing.phone',
                          placeholder: '(435-753-4732)',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.refund.billing.phone,
                          usePhoneFormat: true,
                          onChange: true,
                          required: true,
                          autoComplete: 'tel',
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-6 form-group ${(captcha || this.state.form.refund.billing.email_validated) ? 'was-validated' : ''}`,
                          className: 'form-control form-group',
                          label: 'Email*',
                          placeholder: '(your@email.com)',
                          name: `refund.billing.email`,
                          type: 'email',
                          value: this.state.form.refund.billing.email,
                          onChange: true,
                          useEmailFormat: true,
                          feedback: (
                            <span className={`${emailRegex.test(this.state.form.refund.billing.email) ? 'd-none' : 'text-danger'}`}>
                              Please enter a valid email
                            </span>
                          ),
                          required: true,
                        },
                        {
                          field: 'InlineRadioField',
                          wrapperClass: `col-12 ${(captcha || this.state.form.refund.billing.is_foreign_validated) ? 'was-validated' : ''}`,
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
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.refund.billing.street_address_validated) ? 'was-validated' : ''}`,
                          label: 'Billing Street*',
                          name: 'refund.billing.street_address',
                          placeholder: '(1755 N 400 E)',
                          type: 'text',
                          value: this.state.form.refund.billing.street_address || '',
                          onChange: true,
                          autoComplete: 'billing address-line1',
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.refund.billing.extended_address_validated) ? 'was-validated' : ''}`,
                          label: 'Billing Street 2',
                          placeholder: '(Ste 201)',
                          name: 'refund.billing.extended_address',
                          type: 'text',
                          value: this.state.form.refund.billing.extended_address || '',
                          onChange: true,
                          autoComplete: 'billing address-line2',
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-12 form-group ${(captcha || this.state.form.refund.billing.locality_validated) ? 'was-validated' : ''}`,
                          label: `Billing City${is_foreign ? '' : '*'}`,
                          placeholder: '(Logan)',
                          name: 'refund.billing.locality',
                          type: 'text',
                          value: this.state.form.refund.billing.locality || '',
                          onChange: true,
                          autoComplete: 'billing address-level2',
                          required: !is_foreign
                        },
                        (
                          is_foreign ? (
                            {
                              field: 'TextField',
                              wrapperClass: `col-6 form-group ${(captcha || this.state.form.refund.billing.region_validated) ? 'was-validated' : ''}`,
                              label: 'Billing Province/Parish*',
                              name: 'refund.billing.region',
                              placeholder: "(Smith's Parish)",
                              type: 'text',
                              value: this.state.form.refund.billing.region || '',
                              onChange: true,
                              autoComplete: 'billing address-level1',
                              required: true,
                            }
                          ) : (
                            {
                              field: 'StateSelectField',
                              wrapperClass: `col-6 form-group ${(captcha || this.state.form.refund.billing.region_validated) ? 'was-validated' : ''}`,
                              label: 'Billing State*',
                              name: 'refund.billing.region',
                              value: this.state.form.refund.billing.region || '',
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
                          wrapperClass: `${is_foreign ? 'col-3' : 'col-6'} form-group ${(captcha || this.state.form.refund.billing.postal_code_validated) ? 'was-validated' : ''}`,
                          label: `Billing ${is_foreign ? 'Postal Code' : 'Zip'}*`,
                          name: 'refund.billing.postal_code',
                          placeholder: is_foreign ? '(FL 07)' : '(84321)',
                          type: 'text',
                          value: this.state.form.refund.billing.postal_code || '',
                          onChange: true,
                          autoComplete: 'billing postal-code',
                          required: true,
                          pattern: is_foreign ? null : '[0-9]{4,5}(-[0-9]{4})?'
                        },
                        ...(is_foreign ? [
                          {
                            field: 'CountrySelectField',
                            wrapperClass: `col-6 form-group ${(captcha || this.state.form.refund.billing.country_code_alpha3_validated) ? 'was-validated' : ''}`,
                            label: 'Billing Country*',
                            name: 'refund.billing.country_code_alpha3',
                            value: this.state.form.refund.billing.country_code_alpha3 || '',
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
                        // ...(captcha ? [] : [
                        //   {
                        //     field: 'Recaptcha',
                        //     // className: 'g-recaptcha d-flex justify-content-end',
                        //     wrapperClass: `col-12 form-group`,
                        //     sitekey: '6LfLC3MUAAAAAKlVoWnJU39qEjwdqenGGkvbV7Hq',
                        //     render: 'explicit',
                        //     onVerify: (val) => this.setState({
                        //       captcha: val
                        //     }),
                        //     id: `${this.props.id}-google-verify`
                        //   },
                        // ]),
                        ...(
                            this.allowNext() ? [
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group`,
                                className: `form-control ${
                                  this.state.form.refund.routing_number_validated
                                    ? (this.state.form.refund.routing_number_valid ? 'is-valid' : 'is-invalid')
                                    : ''
                                }`,
                                label: `Routing Number*`,
                                name: 'refund.routing_number',
                                inputMode: 'numeric',
                                placeholder: '(123456789)',
                                type: 'text',
                                value: this.state.form.refund.routing_number || '',
                                onChange: true,
                                autoComplete: 'billing routing-number',
                                required: true,
                              },
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${(captcha || this.state.form.refund.account_number_validated) ? 'was-validated' : ''}`,
                                label: `Account Number*`,
                                name: 'refund.account_number',
                                placeholder: '(123456789012)',
                                type: 'text',
                                value: this.state.form.refund.account_number || '',
                                onChange: true,
                                autoComplete: 'billing account-number',
                                required: true,
                              },
                              {
                                field: 'button',
                                wrapperClass: 'col-12 form-group',
                                className: 'btn btn-primary btn-lg active float-right',
                                type: 'submit',
                                children: [
                                  'Submit Overpayment Request'
                                ]
                              }
                          ] : [
                            {
                              className: 'col-12 text-info text-center',
                              children: [
                                <u key='1'>
                                  ALL required fields(*) must be filled out before entering Bank Info
                                </u>
                              ]
                            }
                          ]
                        )
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
