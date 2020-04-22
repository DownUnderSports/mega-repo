import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import dusIdFormat from 'common/js/helpers/dus-id-format';
import { emailRegex } from 'common/js/helpers/email';

export default class SignUpForm extends Component {
  constructor(props) {
    super(props)

    this.state = {
      successfullySubmitted: false,
      errors: null,
      invalidId: false,
      checkingId: !!props.dusId,
      form: {
        force: false,
        dus_id: dusIdFormat(props.dusId),
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
      clearTimeout(this._checkValid)
      this._checkValid = setTimeout(this.checkCanRequest, 1500)
    }

    return onFormChange(this, k, v, !(/\.?amount$/.test(k) && this.invalidAmount(v)), cb)
  }

  validate(k, regex) {
    if(!regex.test(k)) {
      this.setState({[k + '_valid']: false})
    }
  }

  dusIdFormat(val) {
    return dusIdFormat(val)
  }

  phoneFormat(val) {
    if(val.length) {
      if(val.length > 6) val = val.slice(0, 6) + '-' + val.slice(6)
      if(val.length > 3) val = val.slice(0, 3) + '-' + val.slice(3)
    }
    return val
  }

  componentWillUnmount(){
    clearTimeout(this._checkValid)
  }

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({submitting: true})
    this.handleSubmit()
  }

  checkCanRequest = async () => {
    clearTimeout(this._checkValid)

    if(this.state.form.dus_id) {
      this.setState({
        checkingId: true
      })
      const url = `/api/infokits/${this.state.form.dus_id}/valid`
      try {
        await fetch(url)
        this.setState({
          checkingId: false,
          invalidId: false,
        })
      } catch(e) {
        this.setState({
          checkingId: false,
          invalidId: true,
        })
      }
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
              'email',
              // 'new_password',
              // 'new_password_confirmation',
              'address_attributes'
            ]
      for(let i = 0; i < deletableAttrs.length; i++) {
        delete form[uOrG][deletableAttrs[i]]
      }

      const result =  await fetch('/api/infokits', {
                        method: 'POST',
                        headers: {
                          "Content-Type": "application/json; charset=utf-8"
                        },
                        body: JSON.stringify({infokit: form})
                      }),
            data = await result.json()
      console.log(data)
      this.setState({successfullySubmitted: true, submitting: false})
    } catch(err) {
      try {
        this.setState({errors: (await err.response.json()).errors, submitting: false})
      } catch(e) {
        this.setState({errors: [ err.message ], submitting: false})
      }
    }
  }

  render(){
    const uOrG = this.state.form.type === 'guardian' ? 'guardian' : 'user'
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
                <div className='row'>
                  <div className='col text-center alert alert-success'>
                    <h1 className=''>
                      Your Information Request Has Been Submitted!
                    </h1>
                    <h3>
                      Please allow up to 48 hours for processing.
                    </h3>
                    <p>
                      You will receive an email with more information as soon as possible.
                    </p>
                  </div>
                </div>
              </header>
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
                  <h1>
                    Information Request Form
                  </h1>
                </header>
                <div className="main">
                  <div className="row">
                    <div className="col form-group">
                      <TextField
                        name='infokit[dus_id]'
                        value={this.state.form.dus_id}
                        label='DUS ID'
                        onChange={(e) => this.onChange(e, 'dus_id', 'dusIdFormat')}
                        onBlur={() => this.checkCanRequest()}
                        caretIgnore='-'
                        looseCasing
                        className='form-control'
                        autoComplete='off'
                        required
                      />
                    </div>
                  </div>
                  {
                    this.state.form.dus_id ? (
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
                                    label: 'I am an',
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
                                          label: 'First Name',
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
                                          label: 'Last Name',
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
                                          label: 'First Name',
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
                                          label: 'Last Name',
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
                                          label: 'Gender',
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
                                          label: 'Relation to Athlete',
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
                                              label: 'Phone Number',
                                              name: 'guardian.phone',
                                              type: 'text',
                                              inputMode: 'numeric',
                                              value: this.state.form.guardian.phone,
                                              usePhoneFormat: true,
                                              onChange: true,
                                              required: false,
                                              autoComplete: 'guardian-phone',
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
                                      label: 'Your Contact &amp; Login Info',
                                      fields: [
                                        {
                                          field: 'TextField',
                                          wrapperClass: `form-group ${this.state.form.user.phone_validated ? 'was-validated' : ''}`,
                                          label: 'Phone Number',
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
                                          label: 'Email',
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
                                  field: 'button',
                                  className: 'btn btn-primary btn-lg active float-right',
                                  type: 'submit',
                                  children: [
                                    'Submit Request for Information'
                                  ]
                                }
                              ] : [])
                            ]}
                          />
                        </DisplayOrLoading>
                      )
                    ) : (
                      <div>
                        <h3 className="text-center">
                          A valid DUS ID is required to request an information packet
                        </h3>
                        <hr/>
                        <h5 className="text-center">
                          If you do not know or do not have your DUS ID,
                          please <Link
                            to={
                              `mailto:mail@downundersports.com?subject=No%20DUS%20ID%20available%20for%20Information%20Packet&body=I%20do%20not%20have%20a%20DUS%20ID%20and%20would%20like%20more%20information%20on%20the%20Down%20Under%20Sports%20program.`
                            }
                          >
                            send us an email
                          </Link>, or <Link to='tel:+14357534732'>
                            call our office @ 435-753-4732
                          </Link>
                        </h5>
                      </div>
                    )
                  }
                </div>
              </section>
            </form>
          )
        }
      </DisplayOrLoading>
    )
  }
}
