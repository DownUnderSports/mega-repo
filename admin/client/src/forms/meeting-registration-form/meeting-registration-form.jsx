import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';


export default class MeetingRegistrationForm extends Component {
  constructor(props) {
    super(props)

    const registration = {
      meeting_id: '',
      attended: false,
      duration: '00:00:00'
    }

    const { changes } = Objected.existingOnly(registration, props.registration)

    this.state = {
      errors: null,
      changed: false,
      form: {
        registration: {
          ...registration,
          ...changes
        },
      }
    }

    this.action = `${this.props.url || `/admin/users`}/${this.props.userId}/meeting_registrations/${this.props.id || ''}`
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
    if(!this.state.changed) return this.props.onSuccess()
    try {
      const result =  await fetch(this.action, {
        method: this.props.method || this.props.id ? 'PATCH' : 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify(deleteValidationKeys(Objected.deepClone(this.state.form)))
      });

      await result.json()

      this.props.onSuccess && this.props.onSuccess()
    } catch(err) {
      try {
        this.setState({errors: (await err.response.json()).errors, submitting: false})
      } catch(e) {
        this.setState({errors: [ err.message ], submitting: false})
      }
    }
  }

  render(){
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
          className='registration-form mb-3'
          onSubmit={this.onSubmit}
          onKeyDown={this.onFormKeyDown}
          autoComplete="off"
        >
          <input autoComplete="false" type="text" name="autocomplete" style={{display: 'none'}}/>
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
          <section>
            <div className='main m-0'>
              <DisplayOrLoading display={!this.state.checkingId}>
                <FieldsFromJson
                  onChange={this.onChange}
                  form='registration'
                  fields={[
                    {
                      className: 'row',
                      fields: [
                        {
                          className: 'col mb-3',
                          fields: [
                            {
                              field: 'button',
                              className: 'btn btn-danger btn-lg',
                              type: 'submit',
                              onClick: (e) =>{
                                e.preventDefault();
                                e.stopPropagation();
                                return this.props.onCancel();
                              },
                              children: [
                                'Cancel'
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
                          ]
                        }
                      ]
                    },
                    {
                      className: 'row form-group',
                      fields: [
                        {
                          field: 'MeetingSelectField',
                          onChange: true,
                          valueKey: 'value',
                          viewProps: {
                            className: 'form-control',
                            autoComplete: 'off',
                            required: !!this.state.form.registration.attended,
                          },
                          wrapperClass: `col-12 form-group`,
                          label: 'Select Meeting',
                          name: 'registration.meeting_id',
                          value: this.state.form.registration.meeting_id
                        },
                        {
                          field: 'BooleanField',
                          topLabel: 'Did Attend?',
                          label: 'Attended?',
                          name: 'registration.attended',
                          wrapperClass: 'col-12 form-group',
                          checked: !!this.state.form.registration.attended,
                          value: !!this.state.form.registration.attended,
                          toggle: true,
                          className: ''
                        },
                        ...(this.state.form.registration.attended ? [
                          {
                            field: 'TextField',
                            wrapperClass: `col-12 form-group ${this.state.form.registration.duration_validated ? 'was-validated' : ''}`,
                            label: 'Attended Duration',
                            name: 'registration.duration',
                            type: 'text',
                            value: this.state.form.registration.duration,
                            onChange: true,
                            required: false,
                            autoComplete: 'off',
                            pattern: '\\d{2,}:\\d{2}:\\d{2}'
                          },
                        ] : [])
                      ]
                    },
                    {
                      field: 'button',
                      className: 'btn btn-danger btn-lg',
                      type: 'submit',
                      onClick: (e) =>{
                        e.preventDefault();
                        e.stopPropagation();
                        return this.props.onCancel();
                      },
                      children: [
                        'Cancel'
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
              </DisplayOrLoading>
            </div>
          </section>
        </form>
      </DisplayOrLoading>
    )
  }
}
