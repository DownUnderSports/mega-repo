import React from 'react'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import { Objected } from 'react-component-templates/helpers';

import Component from 'common/js/components/component'
import FieldsFromJson from 'common/js/components/fields-from-json';

import dusIdFormat from 'common/js/helpers/dus-id-format';
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import { emailRegex } from 'common/js/helpers/email';

export default class InfokitForm extends Component {
  constructor(props) {
    super(props)

    const dus_id = props.dusId ? dusIdFormat(props.dusId) : '',
          inStorage = (!!dus_id && (dus_id.length === 7) && sessionStorage.getItem(dus_id)),
          checkingId = inStorage ? !Number(inStorage) : true,
          invalidId = (!!dus_id && !!inStorage) ? !!checkingId || (Number(inStorage) > 1) : false

    this.state = {
      successfullySubmitted: false,
      errors: null,
      invalidId,
      checkingId,
      checkedId: dus_id,
      checkedIds: (!!dus_id && !checkingId) ? { [dus_id]: { invalidId } } : {},
      form: {
        force: false,
        dus_id,
        type: '',
        user: {
          first: '',
          middle: '',
          last: '',
          suffix: '',
          email: '',
          // new_password: '',
          // new_password_confirmation: '',
          address_attributes: {
            is_foreign: false,
            street: '',
            street_2: '',
            street_3: '',
            city: '',
            state_id: null,
            province: '',
            zip: '',
            country: '',
          },
          phone: '',
          can_text: true,
          shirt_size: '',
        },
        guardian: {
          title: '',
          first: '',
          middle: '',
          last: '',
          suffix: '',
          email: '',
          gender: '',
          // new_password: '',
          // new_password_confirmation: '',
          address_attributes: {
            is_foreign: false,
            street: '',
            street_2: '',
            street_3: '',
            city: '',
            state_id: null,
            province: '',
            zip: '',
            country: '',
          },
          phone: '',
          can_text: true,
          shirt_size: '',
        }
      }
    }

    this._checkValid = props.dusId ? setTimeout(this.checkCanRequest, 1500) : false
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter

    if(/dus_id/.test(String(k))) {
      this.setState({checkingId: true})
      clearTimeout(this._checkValid)
    }

    return onFormChange(this, k, v, true, () => {
      if(/dus_id/.test(String(k))) {
        clearTimeout(this._checkValid)
        this._checkValid = setTimeout(this.checkCanRequest, 1500)
      }
      cb()
    })
  }

  validate(k, regex) {
    if(!regex.test(k)) {
      this.setState({[k + '_valid']: false})
    }
  }

  dusIdFormat(val) {
    return dusIdFormat(val)
  }

  componentWillUnmount(){
    clearTimeout(this._checkValid)
  }

  onSubmit = (e) => {
    e.preventDefault();
    const dusId = dusIdFormat(this.state.form.dus_id)
    if(this.state.invalidId || !dusId || (dusId.length !== 7) || (this.state.checkedId !== dusId)) return false
    this.setState({submitting: true})
    this.handleSubmit()
  }

  checkCanRequest = async () => {
    clearTimeout(this._checkValid)
    const { form: { dus_id: dusId }, checkedIds = {} } = this.state

    if(dusId) {
      if(!checkedIds[dusId]) {
        await this.setStateAsync({ checkingId: true, checkedId: dusId, invalidId: false })
        const url = `/api/infokits/${dusId}/valid`
        try {
          await fetch(url)
          checkedIds[dusId] = {
            invalidId: false,
          }
        } catch(e) {
          checkedIds[dusId] = {
            invalidId: true,
          }
        }
      }
      this.setState({
        ...checkedIds[dusId],
        checkingId: false,
        checkedIds
      })
    } else {
      this.setState({
        invalidId: false,
        checkingId: false,
      })
    }

  }

  handleSubmit = async () => {
    try {
      const form = deleteValidationKeys(Objected.deepClone(this.state.form)),
            uOrG = form.type === 'guardian' ? 'user' : 'guardian',
            deletableAttrs = [
              // 'email',
              // 'new_password',
              // 'new_password_confirmation',
              'address_attributes'
            ]
      for(let i = 0; i < deletableAttrs.length; i++) {
        delete form[uOrG][deletableAttrs[i]]
      }

      if(uOrG === 'guardian') {
        if(!form.guardian.email && !form.guardian.phone) {
          throw new Error('A valid email or phone number for your legal guardian is required')
        } else if(form.guardian.email && (form.guardian.email === form.user.email)) {
          throw new Error("Your email and Guardian email cannot be the same")
        } else if(form.guardian.phone && (form.guardian.phone === form.user.phone)) {
          throw new Error("Your phone and Guardian phone cannot be the same")
        }
      }

      const result =  await fetch('/api/infokits', {
                        method: 'POST',
                        headers: {
                          "Content-Type": "application/json; charset=utf-8"
                        },
                        body: JSON.stringify({infokit: form})
                      })
      await result.json()
      this.setState({successfullySubmitted: true, submitting: false})
    } catch(err) {
      console.error(err)
      try {
        this.setState({errors: (await err.response.json()).errors, submitting: false})
      } catch(e) {
        this.setState({errors: [ err.message ], submitting: false})
      }
    }
  }

  get errorsSection() {
    return (
      <div className="row">
        <div className="col">
          {
            this.state.errors && (
              <div className="alert alert-danger form-group" role="alert">
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
            )
          }
        </div>
      </div>
    )
  }

  render(){
    const uOrG = this.state.form.type === 'guardian' ? 'guardian' : 'user',
          dusId = dusIdFormat(this.state.form.dus_id)
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
                    <h1 className=''>
                      Your Information Request Has Been Submitted!
                    </h1>
                    <p>
                      Your next step is to view our information video where we will cover pricing, fundraising opportunities, travel dates and available discounts.
                    </p>
                  </div>
                </div>
              </header>
              <div className='row'>
                <Link to={`/videos/i/${dusId}`} className='btn btn-block btn-primary' style={{fontSize: '1.15rem'}}>
                  Click here to continue to our information video.
                </Link>
              </div>
            </section>
          ) : (
            <form
              action={this.action}
              method='post'
              className='infokit-form'
              onSubmit={this.onSubmit}
            >
              <section>
                <header>
                  { this.errorsSection }
                  <h1>
                    Information Request Form
                  </h1>
                </header>
                <div className="row">
                  <div className="col form-group">
                    <TextField
                      name='infokit[dus_id]'
                      value={this.state.form.dus_id}
                      label='DUS ID'
                      onChange={(e) => this.onChange(e, 'dus_id', 'dusIdFormat')}
                      onBlur={this.checkCanRequest}
                      caretIgnore='-'
                      looseCasing
                      className='form-control'
                      autoComplete='off'
                      required
                    />
                  </div>
                </div>
                {
                  dusId && (dusId.length === 7) && (this.state.checkedId === dusId) ? (
                    this.state.invalidId ? (
                      <div>
                        <h3 className="text-center">
                          Invalid DUS ID Entered or Information Request Already Submitted.
                        </h3>
                        <hr/>
                        <h5 className="text-center">
                          If you believe you have reached this message in error,
                          please <Link
                            to={
                              `mailto:mail@downundersports.com?subject=Invalid%20ID%20for%20Information%20Packet%3A%20${encodeURIComponent(this.state.form.dus_id)}&body=I%20tried%20to%20submit%20a%20request%20for%20more%20information%2C%20but%20received%20an%20Invalid%20DUS%20ID%20error.`
                            }
                          >
                            send us an email
                          </Link>, or <Link to='tel:+14357534732'>
                            call our office @ 435-753-4732
                          </Link>
                        </h5>
                      </div>
                    ) : (
                      <DisplayOrLoading display={!this.state.checkingId}>
                        <hr/>
                        <FieldsFromJson
                          onChange={this.onChange}
                          form='infokit'
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
                                    {value: 'guardian', label: 'Guardian'},
                                  ],
                                  className:'',
                                  required: true,
                                }
                              ]
                            },
                            ...(this.state.form.type ? [
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
                                        wrapperClass: `col-lg-4 form-group ${this.state.form.user.first_validated ? 'was-validated' : ''}`,
                                        label: 'First Name*',
                                        name: 'user.first',
                                        type: 'text',
                                        value: this.state.form.user.first,
                                        onChange: true,
                                        required: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'given-name' : 'athlete-given-name',
                                      },
                                      {
                                        field: 'TextField',
                                        wrapperClass: `col-lg-3 form-group ${this.state.form.user.middle_validated ? 'was-validated' : ''}`,
                                        label: 'Middle Name',
                                        name: 'user.middle',
                                        type: 'text',
                                        value: this.state.form.user.middle,
                                        onChange: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'additional-name' : 'athlete-additional-name',
                                      },
                                      {
                                        field: 'TextField',
                                        wrapperClass: `col-lg-4 form-group ${this.state.form.user.last_validated ? 'was-validated' : ''}`,
                                        label: 'Last Name*',
                                        name: 'user.last',
                                        type: 'text',
                                        value: this.state.form.user.last,
                                        onChange: true,
                                        required: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'family-name' : 'athlete-family-name',
                                      },
                                      {
                                        field: 'TextField',
                                        wrapperClass: `col-lg-1 form-group ${this.state.form.user.suffix_validated ? 'was-validated' : ''}`,
                                        label: 'Suffix',
                                        name: 'user.suffix',
                                        type: 'text',
                                        value: this.state.form.user.suffix,
                                        onChange: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'honorific-suffix' : 'athlete-honorific-suffix',
                                      },
                                    ]
                                  },
                                  ...(
                                    (this.state.errors && (/extremely/.test(this.state.errors[0]))) ? [
                                      {
                                        className: 'row',
                                        fields: [
                                          {
                                            field: 'BooleanField',
                                            topLabel: 'This is the Athlete\'s Name?',
                                            label: 'Check this box if you are sure that this this the correct ATHLETE name',
                                            name: 'force',
                                            wrapperClass: 'col-12 form-group',
                                            checked: !!this.state.form.force,
                                            value: !!this.state.form.force,
                                            toggle: true,
                                            className: ''
                                          },
                                        ]
                                      }
                                    ] : []
                                  )
                                ]
                              },
                              {
                                field: 'hr',
                              },
                              {
                                field: 'CardSection',
                                label: 'Primary Parent/Guardian Information',
                                subLabel: (
                                  (this.state.form.type === 'athlete') ?
                                  '<i>Must be your legal guardian</i>' :
                                  '<i>Must be a legal guardian of the athlete</i>'
                                ),
                                fields: [
                                  {
                                    className: 'row',
                                    fields: [
                                      {
                                        field: 'TextField',
                                        wrapperClass: `col-lg-1 form-group ${this.state.form.guardian.title_validated ? 'was-validated' : ''}`,
                                        label: 'Title',
                                        name: 'guardian.title',
                                        type: 'text',
                                        value: this.state.form.guardian.title,
                                        onChange: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'guardian-honorific-prefix' : 'honorific-prefix',
                                      },
                                      {
                                        field: 'TextField',
                                        wrapperClass: `col-lg-3 form-group ${this.state.form.guardian.first_validated ? 'was-validated' : ''}`,
                                        label: 'First Name*',
                                        name: 'guardian.first',
                                        type: 'text',
                                        value: this.state.form.guardian.first,
                                        onChange: true,
                                        required: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'guardian-given-name' : 'given-name',
                                      },
                                      {
                                        field: 'TextField',
                                        wrapperClass: `col-lg-3 form-group ${this.state.form.guardian.middle_validated ? 'was-validated' : ''}`,
                                        label: 'Middle Name',
                                        name: 'guardian.middle',
                                        type: 'text',
                                        value: this.state.form.guardian.middle,
                                        onChange: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'guardian-additional-name' : 'additional-name',
                                      },
                                      {
                                        field: 'TextField',
                                        wrapperClass: `col-lg-4 form-group ${this.state.form.guardian.last_validated ? 'was-validated' : ''}`,
                                        label: 'Last Name*',
                                        name: 'guardian.last',
                                        type: 'text',
                                        value: this.state.form.guardian.last,
                                        onChange: true,
                                        required: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'guardian-family-name' : 'family-name',
                                      },
                                      {
                                        field: 'TextField',
                                        wrapperClass: `col-lg-1 form-group ${this.state.form.guardian.suffix_validated ? 'was-validated' : ''}`,
                                        label: 'Suffix',
                                        name: 'guardian.suffix',
                                        type: 'text',
                                        value: this.state.form.guardian.suffix,
                                        onChange: true,
                                        autoComplete: (this.state.form.type === 'athlete') ? 'guardian-honorific-suffix' : 'honorific-suffix',
                                      },
                                      {
                                        field: 'InlineRadioField',
                                        wrapperClass: `col-12 form-group ${this.state.form.guardian.gender_validated ? 'was-validated' : ''}`,
                                        name: 'guardian.gender',
                                        value: this.state.form.guardian.gender,
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
                                        field: 'SelectField',
                                        wrapperClass: `col-lg-6 form-group ${this.state.form.guardian.relationship_validated ? 'was-validated' : ''}`,
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
                                      ...(
                                        this.state.form.type !== 'guardian' ? [
                                          {
                                            field: 'TextField',
                                            wrapperClass: `col-lg-6 form-group ${this.state.form.guardian.phone_validated ? 'was-validated' : ''}`,
                                            label: `Phone Number${this.state.form.guardian.email ? '' : '*'}`,
                                            name: 'guardian.phone',
                                            type: 'text',
                                            inputMode: 'numeric',
                                            value: this.state.form.guardian.phone,
                                            usePhoneFormat: true,
                                            onChange: true,
                                            required: !this.state.form.guardian.email,
                                            autoComplete: 'guardian-phone',
                                          },
                                          {
                                            field: 'TextField',
                                            wrapperClass: ` col-lg-6 form-group ${this.state.form.guardian.email_validated ? 'was-validated' : ''}`,
                                            className: 'form-control form-group',
                                            label: `Email${this.state.form.guardian.phone ? '' : '*'}`,
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
                                            required: !this.state.form.guardian.phone,
                                            autoComplete: 'guardian-email'
                                          },
                                        ] : []
                                      )
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
                                    wrapperClass: 'col-12 col-md-6',
                                    className: '',
                                    label: 'Home Mailing Address',
                                    name: `${uOrG}.address_attributes`,
                                    valuePrefix: `${uOrG}.address_attributes`,
                                    delegatedChange: true,
                                    values: this.state.form[uOrG].address_attributes,
                                    required: true,
                                  },
                                  {
                                    field: 'CardSection',
                                    wrapperClass: 'col-12 col-md-6',
                                    className: '',
                                    label: 'Your Contact Info',
                                    fields: [
                                      {
                                        field: 'TextField',
                                        wrapperClass: `form-group ${this.state.form.user.phone_validated ? 'was-validated' : ''}`,
                                        label: 'Phone Number*',
                                        name: `${uOrG}.phone`,
                                        type: 'text',
                                        inputMode: 'numeric',
                                        value: this.state.form[uOrG].phone,
                                        usePhoneFormat: true,
                                        onChange: true,
                                        required: true,
                                      },
                                      {
                                        field: 'TextField',
                                        wrapperClass: `form-group ${this.state.form[uOrG].email_validated ? 'was-validated' : ''}`,
                                        className: 'form-control form-group',
                                        label: 'Email*',
                                        name: `${uOrG}.email`,
                                        type: 'email',
                                        value: this.state.form[uOrG].email,
                                        onChange: true,
                                        useEmailFormat: true,
                                        feedback: (
                                          <span className={`${emailRegex.test(this.state.form[uOrG].email) ? 'd-none' : 'text-danger'}`}>
                                            Please enter a valid email
                                          </span>
                                        ),
                                        required: true,
                                        autoComplete: 'email'
                                      },
                                      // {
                                      //   field: 'PasswordField',
                                      //   wrapperClass: `form-group ${this.state.form[uOrG].new_password_validated ? 'was-validated' : ''}`,
                                      //   className: 'form-control form-group',
                                      //   label: 'Password',
                                      //   name: `${uOrG}.new_password`,
                                      //   value: this.state.form[uOrG].new_password,
                                      //   confirmationValue: this.state.form[uOrG].new_password_confirmation,
                                      //   onChange: true,
                                      //   onConfirmationChange: true,
                                      //   hasConfirmation: true,
                                      //   required: true,
                                      // },
                                    ]
                                  },
                                ]
                              },
                              {
                                className: 'row',
                                fields: [
                                  {
                                    className: 'col'
                                  },
                                  {
                                    className: 'col-auto',
                                    fields: [
                                      {
                                        field: 'button',
                                        className: 'btn btn-primary btn-lg active mb-3',
                                        type: 'submit',
                                        children: [
                                          'Submit Request for Information'
                                        ]
                                      }
                                    ]
                                  },
                                ]
                              }
                            ] : [])
                          ]}
                        />
                        { this.errorsSection }
                      </DisplayOrLoading>
                    )
                  ) : (
                    <div>
                      <ul>
                        <li>
                          A valid DUS ID is required to request an information packet
                        </li>
                        <li>
                          Your DUS ID can be found at the top of your invitation
                        </li>
                        <li>
                          Your DUS ID links your submission to your invitation in our database
                        </li>
                        <li>
                          <u>Do not use someone else's DUS ID or give your DUS ID to another athlete</u>
                        </li>
                      </ul>
                      <Link
                        to="/open-tryouts"
                        className="btn btn-info btn-block btn-lg mt-4"
                      >
                        Click here if you do not know, or do not have, your DUS ID
                      </Link>
                    </div>
                  )
                }
              </section>
            </form>
          )
        }
      </DisplayOrLoading>
    )
  }
}
