import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';

export default class PaymentLookupForm extends Component {
  constructor(props) {
    super(props)

    this.state = {
      captcha: '',
      receiptId: null,
      errors: null,
      changed: false,
      showDropInForm: false,
      form: {
        state_id: props.stateId || '',
        sport_id: props.sportId || '',
        transaction_id: '',
        payment: {
          gateway_type: 'auth_net',
          split: [],
        },
      }
    }

    this.action = `${props.url || `/api/users/${props.id || ''}/payments/lookup`}`
  }

  allowNext = () => {
    const values = this.state.form.payment
    return !!(
      this.state.form.transaction_id
      // && this.state.captcha
    )
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter

    return onFormChange(this, k, v, true, cb)
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
    const { breakPoint = 'col-md-6', teamSelect, minimum } = this.props

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
          className='payment-lookup-form mb-3'
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
                          wrapperClass: `col-md-6 form-group ${this.state.form.transaction_id_validated ? 'was-validated' : ''}`,
                          label: 'Transaction ID*',
                          name: 'transaction_id',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.transaction_id || '',
                          onChange: true,
                          autoComplete: 'off',
                          placeholder: '(000000000000000000)',
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
                                    autoComplete: 'off',
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
                                    autoComplete: 'off',
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
                                  value: this.state.form.payment.split[i].dus_id || '',
                                  onChange: true,
                                  autoComplete: 'off',
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-6 form-group was-validated`,
                                  label: `Split Amount ${i + 1}`,
                                  name: `payment.split.${i}.amount`,
                                  type: 'text',
                                  value: this.state.form.payment.split[i].amount || '',
                                  onChange: true,
                                  autoComplete: 'off',
                                  feedback: `Apply $${this.state.form.payment.split[i].amount || '0'} of $${this.state.form.payment.amount || 0} to ${this.state.form.payment.split[i].dus_id}`
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
                        // {
                        //   field: 'Recaptcha',
                        //   // className: 'g-recaptcha d-flex justify-content-end',
                        //   wrapperClass: `${breakPoint} form-group`,
                        //   sitekey: '6LfLC3MUAAAAAKlVoWnJU39qEjwdqenGGkvbV7Hq',
                        //   render: 'explicit',
                        //   onVerify: (val) => this.setState({
                        //     captcha: val
                        //   }),
                        //   id: `${this.props.id}-google-verify`
                        // },
                        ...(
                          this.allowNext() ? [
                            {
                              field: 'input',
                              type: 'hidden',
                              name: 'payment.gateway_type',
                              value: this.state.form.payment.gateway_type,
                            },
                            {
                              field: 'button',
                              wrapperClass: 'col-12 form-group',
                              className: 'btn btn-primary btn-lg active float-right',
                              type: 'submit',
                              children: [
                                `Submit Payment Lookup`
                              ]
                            }
                          ] : [
                            {
                              className: 'col-12 text-info text-center',
                              children: [
                                <u key='1'>
                                  ALL required fields(*) must be filled out before submitting
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
