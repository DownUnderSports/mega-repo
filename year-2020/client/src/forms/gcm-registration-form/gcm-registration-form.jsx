import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';
import { allowBlankEmailRegex as emailRegex } from 'common/js/helpers/email';

const blankRegistration = {
        id: '',
        registered_date: '',
        confirmation: '',
        email: 'gcm-registrations@downundersports.com',
      }

export default class GCMRegistrationForm extends Component {
  constructor(props) {
    super(props)

    const registration = Objected.deepClone(blankRegistration)

    const { changes } = Objected.existingOnly(registration, props.registration)

    this.state = {
      errors: null,
      changed: false,
      form: {
        ...registration,
        ...changes
      }
    }

    this.action = `${
      this.props.url
      || '/admin/traveling/gcm_registrations'
    }/${
      this.props.userId
    }`
  }

  componentDidUpdate({userId, url}) {
    if(
      (this.props.url !== url)
      || (this.props.userId !== userId)
    ) {
      this.action = `${
        this.props.url
        || '/admin/traveling/gcm_registrations'}/${this.props.userId
      }`
    }
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter

    if(/dus_id/.test(String(k))) {
      clearTimeout(this._checkValid)
      this._checkValid = setTimeout(this.checkCanRequest, 1500)
    }

    return onFormChange(this, k, v, true, cb)
  }

  validate(k, regex) {
    if(!regex.test(k)) {
      this.setState({[k + '_valid']: false})
    }
  }

  onFormKeyDown = (e) => {
    if((e.keyCode === 13) && e.ctrlKey) this.onSubmit(e)
  }

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({submitting: true})
    this.handleSubmit()
  }

  handleSubmit = async () => {
    if(!this.state.changed) return this.onSuccess()
    try {
      const result = await fetch(this.action, {
        method: 'PATCH',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({
          user: {
            marathon_registration_attributes: deleteValidationKeys(
              Objected.deepClone(this.state.form)
            )
          }
        })
      });

      await result.json()

      this.setState({ submitting: false }, this.onSuccess)

    } catch(err) {
      try {
        this.setState({errors: (await err.response.json()).errors, submitting: false})
      } catch(e) {
        this.setState({errors: [ err.registration ], submitting: false})
      }
    }
  }

  onSuccess = () => this.setState({ completed: true }, () => {
    setTimeout(this.props.onSuccess || this.unComplete, 2500)
  })

  unComplete = () => this.setState({ completed: false })

  render(){
    const { form, errors, submitting, completed = false } = this.state

    return completed ? (
      <div className="row">
        <div className="col">
          <div className="alert alert-success form-group" role="alert">
            Successfully Submitted! You will be redirected shortly
          </div>
        </div>
      </div>
    ) : (
      <DisplayOrLoading
        display={!submitting}
        loadingElement={<JellyBox className="page-loader" />}
      >
        <form
          action={this.action}
          method='post'
          className='registration-form mb-3'
          onSubmit={this.onSubmit}
          onKeyDown={this.onFormKeyDown}
          autoComplete="off"
        >
          <input autoComplete="false" type="text" name="autocomplete" style={{display: 'none'}}/>
          <div className="row">
            <div className="col">
              {
                errors && <div className="alert alert-danger form-group" role="alert">
                  {
                    errors.map((v, k) => (
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
          <div className="m-0">
            <FieldsFromJson
              onChange={this.onChange}
              form='registration'
              fields={[
                {
                  className: 'row form-group',
                  fields: [
                    {
                      field: 'CalendarField',
                      wrapperClass: 'col-xs-12 col-md-8 col-lg-6 form-group was-validated',
                      label: 'Registration Date (YYYY-MM-DD)',
                      name: 'registered_date',
                      type: 'text',
                      value: form.registered_date,
                      valueKey: 'value',
                      pattern: "\\d{4}-\\d{2}-\\d{2}",
                      onChange: true,
                      autoComplete: 'off',
                      closeOnSelect: true,
                      required: true
                    },
                    {
                      field: 'TextField',
                      wrapperClass: 'col-xs-12 col-md-8 col-lg-6 form-group was-validated',
                      label: 'Confirmation',
                      name: 'confirmation',
                      type: 'text',
                      value: form.confirmation,
                      onChange: true,
                      required: true,
                      autoComplete: 'off',
                    },
                    {
                      field: 'TextField',
                      wrapperClass: 'col-xs-12 col-md-8 col-lg-6 form-group was-validated',
                      label: 'Email',
                      name: `email`,
                      type: 'email',
                      value: form.email,
                      onChange: true,
                      useEmailFormat: true,
                      required: true,
                      autoComplete: 'off',
                      feedback: (
                        <span className={`${emailRegex.test(form.email) ? 'd-none' : 'text-danger'}`}>
                          Please enter a valid email
                        </span>
                      ),
                    },
                  ]
                },
                {
                  field: 'button',
                  className: 'btn btn-primary btn-lg active float-right',
                  type: 'submit',
                  children: [
                    'Submit'
                  ]
                }
              ]}
            />
          </div>
        </form>
      </DisplayOrLoading>
    )
  }
}
