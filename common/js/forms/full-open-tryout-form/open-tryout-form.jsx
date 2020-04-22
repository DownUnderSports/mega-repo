import React from 'react'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { DisplayOrLoading } from 'react-component-templates/components';
import { Objected } from 'react-component-templates/helpers';

import Component from 'common/js/components/component'
import FieldsFromJson from 'common/js/components/fields-from-json';

import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import { emailRegex } from 'common/js/helpers/email';

export default class OpenTryoutForm extends Component {
  constructor(props) {
    super(props)

    this.badAutoComplete = `false-${+(new Date())}`

    this.state = {
      successfullySubmitted: false,
      errors: null,
      form: {
        force: false,
        type: '',
        athlete: {
          first: '',
          middle: '',
          last: '',
          suffix: '',
          email: '',
          gender: '',
          phone: '',
          grad: '',
          stats: '',
          school_name: '',
          school_city: '',
          school_state_id: null,
          sport_id: null,
        },
        guardian: {
          relationship: null,
          title: '',
          first: '',
          middle: '',
          last: '',
          suffix: '',
          email: '',
          phone: '',
        },
        address: {
          is_foreign: false,
          street: '',
          street_2: '',
          street_3: '',
          city: '',
          state_id: null,
          province: '',
          zip: '',
          country: '',
        }
      }
    }
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

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({submitting: true})
    this.handleSubmit()
  }

  handleSubmit = async () => {
    try {
      let query
      try {
        query = window.location.search
          .slice(1)
          .split('&')
          .map(p => p.split('='))
          .reduce((obj, [key, value]) => ({ ...obj, [key]: value }), {})
      } catch(_) {
        query = {}
      }

      const form = deleteValidationKeys(Objected.deepClone(this.state.form)),
            result =  await fetch('/api/tryouts', {
                        method: 'POST',
                        headers: {
                          "Content-Type": "application/json; charset=utf-8"
                        },
                        body: JSON.stringify({tryout: form, query })
                      })
      await result.json()
      this.setState({successfullySubmitted: true, submitting: false})
    } catch(err) {
      try {
        const jsonResp = await err.response.json()
        this.setState({errors: jsonResp.errors || [ jsonResp.error ], submitting: false})
      } catch(e) {
        this.setState({errors: [ err.message ], submitting: false})
      }
    }
  }

  render(){
    const isAthlete = (this.state.form.type === 'athlete'),
          autoComplete = this.badAutoComplete || `false-${+(new Date())}`

    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        {
          this.state.successfullySubmitted ? (
            <section>
              <header>
                <div className='row mb-3'>
                  <div className='col text-center alert alert-success'>
                    <h1>
                      { this.props.afterSubmit || 'Your Tryout Information Has Been Submitted!' }
                    </h1>
                  </div>
                </div>
              </header>
              <p>
                We will review your application as soon as possible, and be in touch shortly.
              </p>
            </section>
          ) : (
            <form
              action={this.action}
              method='post'
              className='tryout-form'
              onSubmit={this.onSubmit}
            >
              <section>
                <header>
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
                  <h3>
                    { this.props.header || 'Open Tryout Form' }
                  </h3>
                </header>
                <DisplayOrLoading display={!this.state.checkingId}>
                  <hr/>
                  <FieldsFromJson
                    onChange={this.onChange}
                    form='tryout'
                    fields={[
                      {
                        wrapperClass: 'row',
                        className: `col form-group ${this.state.form.type_validated ? 'was-validated' : ''}`,
                        fields: [
                          {
                            field: 'InlineRadioField',
                            name: 'type',
                            value: this.state.form.type,
                            label: 'I am an*',
                            onChange: true,
                            options: [
                              {value: 'athlete', label: 'Athlete'},
                              {value: 'guardian', label: 'Parent/Legal Guardian'},
                            ],
                            className:'',
                            required: true,
                            autoComplete
                          }
                        ]
                      },
                      ...(this.state.form.type ? [
                        {
                          field: 'CardSection',
                          label: 'School/Sport Information',
                          fields: [
                            {
                              className: 'row',
                              fields: [
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.athlete.grad_validated ? 'was-validated' : ''}`,
                                  label: 'Graduation Year*',
                                  name: 'athlete.grad',
                                  type: 'numeric',
                                  value: this.state.form.athlete.grad,
                                  pattern: "(20)?[2-3][0-9]",
                                  onChange: true,
                                  required: true,
                                  autoComplete
                                },
                                {
                                  field: 'SportSelectField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.athlete.sport_id_validated ? 'was-validated' : ''}`,
                                  className:'col',
                                  viewProps: {
                                    className:'form-control',
                                  },
                                  label: 'Sport*',
                                  name: 'athlete.sport_id',
                                  value: this.state.form.athlete.sport_id,
                                  valueKey: 'value',
                                  clientOnly: true,
                                  onChange: true,
                                  required: true,
                                  autoComplete
                                },
                                {
                                  field: 'TextAreaField',
                                  wrapperClass: `col-12 form-group ${this.state.form.athlete.stats_validated ? 'was-validated' : ''}`,
                                  label: 'Relevant Stats/Honors*',
                                  name: 'athlete.stats',
                                  type: 'text',
                                  value: this.state.form.athlete.stats,
                                  rows: 5,
                                  onChange: true,
                                  required: true,
                                  autoComplete
                                },
                                {
                                  field: 'hr',
                                  wrapperClass: 'col-12',
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.athlete.school_name_validated ? 'was-validated' : ''}`,
                                  label: 'School Name*',
                                  name: 'athlete.school_name',
                                  type: 'text',
                                  value: this.state.form.athlete.school_name,
                                  onChange: true,
                                  required: true,
                                  autoComplete
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.athlete.school_city_validated ? 'was-validated' : ''}`,
                                  label: 'School City*',
                                  name: 'athlete.school_city',
                                  type: 'text',
                                  value: this.state.form.athlete.school_city,
                                  onChange: true,
                                  required: true,
                                  autoComplete
                                },
                                {
                                  field: 'StateSelectField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.athlete.school_state_id_validated ? 'was-validated' : ''}`,
                                  className:'col',
                                  viewProps: {
                                    className:'form-control',
                                    autoComplete
                                  },
                                  label: 'School State*',
                                  name: 'athlete.school_state_id',
                                  value: this.state.form.athlete.school_state_id,
                                  valueKey: 'value',
                                  onChange: true,
                                  autoComplete
                                },
                              ]
                            }
                          ]
                        },
                        {
                          field: 'hr',
                        },
                        {
                          field: 'CardSection',
                          label: 'Athlete Information',
                          fields: [
                            {
                              className: 'row',
                              fields: [
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.athlete.first_validated ? 'was-validated' : ''}`,
                                  // wrapperClass: `col-lg-4 form-group ${this.state.form.athlete.first_validated ? 'was-validated' : ''}`,
                                  label: 'First Name*',
                                  name: 'athlete.first',
                                  type: 'text',
                                  value: this.state.form.athlete.first,
                                  onChange: true,
                                  required: true,
                                  autoComplete: isAthlete ? 'given-name' : 'athlete-given-name',
                                },
                                // {
                                //   field: 'TextField',
                                //   wrapperClass: `col-lg-3 form-group ${this.state.form.athlete.middle_validated ? 'was-validated' : ''}`,
                                //   label: 'Middle Name',
                                //   name: 'athlete.middle',
                                //   type: 'text',
                                //   value: this.state.form.athlete.middle,
                                //   onChange: true,
                                //   autoComplete: isAthlete ? 'additional-name' : 'athlete-additional-name',
                                // },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.athlete.last_validated ? 'was-validated' : ''}`,
                                  // wrapperClass: `col-lg-4 form-group ${this.state.form.athlete.last_validated ? 'was-validated' : ''}`,
                                  label: 'Last Name*',
                                  name: 'athlete.last',
                                  type: 'text',
                                  value: this.state.form.athlete.last,
                                  onChange: true,
                                  required: true,
                                  autoComplete: isAthlete ? 'family-name' : 'athlete-family-name',
                                },
                                // {
                                //   field: 'TextField',
                                //   wrapperClass: `col-lg-1 form-group ${this.state.form.athlete.suffix_validated ? 'was-validated' : ''}`,
                                //   label: 'Suffix',
                                //   name: 'athlete.suffix',
                                //   type: 'text',
                                //   value: this.state.form.athlete.suffix,
                                //   onChange: true,
                                //   autoComplete: isAthlete ? 'honorific-suffix' : 'athlete-honorific-suffix',
                                // },
                                {
                                  field: 'InlineRadioField',
                                  wrapperClass: `col-12 form-group ${this.state.form.athlete.gender_validated ? 'was-validated' : ''}`,
                                  name: 'athlete.gender',
                                  value: this.state.form.athlete.gender,
                                  label: 'Gender*',
                                  onChange: true,
                                  options: [
                                    {value: 'M', label: 'Male'},
                                    {value: 'F', label: 'Female'},
                                  ],
                                  required: true,
                                  className: ''
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.athlete.phone_validated ? 'was-validated' : ''}`,
                                  label: 'Phone Number',
                                  name: 'athlete.phone',
                                  type: 'text',
                                  inputMode: 'numeric',
                                  value: this.state.form.athlete.phone,
                                  usePhoneFormat: true,
                                  onChange: true,
                                  required: false,
                                  autoComplete: isAthlete ? 'phone' : 'athlete-phone',
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: ` col-lg-6 form-group ${this.state.form.athlete.email_validated ? 'was-validated' : ''}`,
                                  className: 'form-control form-group',
                                  label: 'Email',
                                  name: 'athlete.email',
                                  type: 'email',
                                  value: this.state.form.athlete.email,
                                  onChange: true,
                                  useEmailFormat: true,
                                  feedback: (
                                    <span className={`${(!this.state.form.athlete.email || emailRegex.test(this.state.form.athlete.email)) ? 'd-none' : 'text-danger'}`}>
                                      Please enter a valid email
                                    </span>
                                  ),
                                  required: false,
                                  autoComplete: isAthlete ? 'email' : 'athlete-email',
                                },
                              ]
                            }
                          ]
                        },
                        {
                          field: 'hr',
                        },
                        {
                          field: 'CardSection',
                          label: 'Primary Parent/Guardian Information',
                          subLabel: '<i>Must be a legal guardian of the athlete</i>',
                          fields: [
                            {
                              className: 'row',
                              fields: [
                                {
                                  field: 'SelectField',
                                  wrapperClass: `col-12 form-group ${this.state.form.guardian.relationship_validated ? 'was-validated' : ''}`,
                                  className:'col',
                                  viewProps: {
                                    className:'form-control',
                                  },
                                  label: 'Relation to Athlete*',
                                  name: 'guardian.relationship',
                                  options: [
                                    {
                                      value: 'parent',
                                      label: 'Parent',
                                    },
                                    {
                                      value: 'guardian',
                                      label: 'Guardian',
                                    },
                                  ],
                                  value: this.state.form.guardian.relationship,
                                  valueKey: 'value',
                                  onChange: true
                                },
                                // {
                                //   field: 'TextField',
                                //   wrapperClass: `col-lg-1 form-group ${this.state.form.guardian.title_validated ? 'was-validated' : ''}`,
                                //   label: 'Title',
                                //   name: 'guardian.title',
                                //   type: 'text',
                                //   value: this.state.form.guardian.title,
                                //   onChange: true,
                                //   autoComplete: isAthlete ? 'guardian-honorific-prefix' : 'honorific-prefix',
                                // },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.guardian.first_validated ? 'was-validated' : ''}`,
                                  // wrapperClass: `col-lg-3 form-group ${this.state.form.guardian.first_validated ? 'was-validated' : ''}`,
                                  label: 'First Name*',
                                  name: 'guardian.first',
                                  type: 'text',
                                  value: this.state.form.guardian.first,
                                  onChange: true,
                                  required: true,
                                  autoComplete: isAthlete ? 'guardian-given-name' : 'given-name',
                                },
                                // {
                                //   field: 'TextField',
                                //   wrapperClass: `col-lg-3 form-group ${this.state.form.guardian.middle_validated ? 'was-validated' : ''}`,
                                //   label: 'Middle Name',
                                //   name: 'guardian.middle',
                                //   type: 'text',
                                //   value: this.state.form.guardian.middle,
                                //   onChange: true,
                                //   autoComplete: isAthlete ? 'guardian-additional-name' : 'additional-name',
                                // },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.guardian.last_validated ? 'was-validated' : ''}`,
                                  // wrapperClass: `col-lg-4 form-group ${this.state.form.guardian.last_validated ? 'was-validated' : ''}`,
                                  label: 'Last Name*',
                                  name: 'guardian.last',
                                  type: 'text',
                                  value: this.state.form.guardian.last,
                                  onChange: true,
                                  required: true,
                                  autoComplete: isAthlete ? 'guardian-family-name' : 'family-name',
                                },
                                // {
                                //   field: 'TextField',
                                //   wrapperClass: `col-lg-1 form-group ${this.state.form.guardian.suffix_validated ? 'was-validated' : ''}`,
                                //   label: 'Suffix',
                                //   name: 'guardian.suffix',
                                //   type: 'text',
                                //   value: this.state.form.guardian.suffix,
                                //   onChange: true,
                                //   autoComplete: isAthlete ? 'guardian-honorific-suffix' : 'honorific-suffix',
                                // },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-lg-6 form-group ${this.state.form.guardian.phone_validated ? 'was-validated' : ''}`,
                                  label: 'Phone Number*',
                                  name: 'guardian.phone',
                                  type: 'text',
                                  inputMode: 'numeric',
                                  value: this.state.form.guardian.phone,
                                  usePhoneFormat: true,
                                  onChange: true,
                                  required: true,
                                  autoComplete: isAthlete ? 'guardian-phone' : 'phone',
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: ` col-lg-6 form-group ${this.state.form.guardian.email_validated ? 'was-validated' : ''}`,
                                  className: 'form-control form-group',
                                  label: 'Email*',
                                  name: 'guardian.email',
                                  type: 'email',
                                  value: this.state.form.guardian.email,
                                  onChange: true,
                                  useEmailFormat: true,
                                  feedback: (
                                    <span className={`${(!this.state.form.guardian.email || emailRegex.test(this.state.form.guardian.email)) ? 'd-none' : 'text-danger'}`}>
                                      Please enter a valid email
                                    </span>
                                  ),
                                  required: true,
                                  autoComplete: isAthlete ? 'guardian-email' : 'email',
                                },
                              ]
                            }
                          ]
                        },
                        {
                          field: 'hr',
                        },
                        {
                          className: 'row',
                          fields: [
                            {
                              field: 'AddressSection',
                              wrapperClass: 'col-12',
                              className: '',
                              label: 'Home Mailing Address',
                              name: 'address',
                              valuePrefix: 'address',
                              delegatedChange: true,
                              values: this.state.form.address,
                              required: true,
                            },
                          ]
                        },
                        {
                          field: 'button',
                          className: 'btn btn-primary btn-lg active float-right mt-3',
                          type: 'submit',
                          children: [
                            'Submit Open Tryout'
                          ]
                        }
                      ] : [])
                    ]}
                  />
                </DisplayOrLoading>
              </section>
            </form>
          )
        }
      </DisplayOrLoading>
    )
  }
}
