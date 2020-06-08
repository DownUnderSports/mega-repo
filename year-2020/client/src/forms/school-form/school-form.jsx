import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers'
import { DisplayOrLoading } from 'react-component-templates/components'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change'
import FieldsFromJson from 'common/js/components/fields-from-json'

const school = {
  pid: '',
  name: '',
  allowed: false,
  allowed_home: false,
  closed: false,
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
  transfer_athletes: ''
}

export default class SchoolForm extends Component {
  constructor(props) {
    super(props)

    const { changes } = Objected.existingOnly(school, props.school)

    this.state = {
      errors: null,
      changed: false,
      form: {
        school: {
          ...school,
          ...changes
        },
      }
    }

    this.action = `${this.props.url || '/admin/schools'}/${this.props.id || ''}`
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
      const form = deleteValidationKeys(Objected.deepClone(this.state.form))

      const result =  await fetch(this.action, {
        method: this.props.method || this.props.id ? 'PATCH' : 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify(form)
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

  documentTitle(){
    return window.document.title === 'Home Page' ? 'Above School' : window.document.title
  }

  render(){
    const cityState      = (this.props.school.location || '').split(', '),
          searchableName = (this.props.school.name || '').replace(/\s/g, '+'),
          googleSchool   = `https://www.google.com/search?q=${searchableName},+${cityState[0]}+${cityState[1]}`,
          ncesSchool     = `https://nces.ed.gov/globallocator/index.asp?search=1&State=${cityState[1]}&city=${cityState[0]}&zipcode=&miles=&itemname=${searchableName}&sortby=name&School=1&PrivSchool=1&College=1`
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
          className='school-form mb-3'
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
                  form='school'
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
                              type: 'cancel',
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
                      className: 'row',
                      fields: [
                        {
                          className: 'col-lg form-group',
                          fields: [
                            {
                              field: 'TextField',
                              wrapperClass: `form-group ${this.state.form.school.name_validated ? 'was-validated' : ''}`,
                              label: 'Name',
                              name: 'school.name',
                              type: 'text',
                              value: this.state.form.school.name,
                              onChange: true,
                              required: true,
                              autoComplete: 'off',
                            },
                            {
                              field: 'p',
                              className: 'help-block',
                              fields: [
                                {
                                  field: 'a',
                                  href: googleSchool,
                                  target: 'SCHOOL_SEARCH_GOOGLE',
                                  children: 'Search Google'
                                }
                              ]
                            }
                          ]
                        },
                        {
                          className: 'col-lg form-group',
                          fields: [
                            {
                              field: 'TextField',
                              wrapperClass: `form-group ${this.state.form.school.pid_validated ? 'was-validated' : ''}`,
                              label: 'PID (NCES School ID)',
                              name: 'school.pid',
                              type: 'text',
                              value: this.state.form.school.pid,
                              onChange: true,
                              required: true,
                              autoComplete: 'off',
                            },
                            {
                              field: 'p',
                              className: 'help-block',
                              fields: [
                                {
                                  field: 'a',
                                  href: ncesSchool,
                                  target: 'SCHOOL_SEARCH_NCES',
                                  children: 'Search NCES'
                                }
                              ]
                            }
                          ]
                        },
                        {
                          field: 'BooleanField',
                          topLabel: 'Allowed?',
                          label: 'Can Send Invites to School?',
                          name: 'school.allowed',
                          wrapperClass: 'col-lg form-group',
                          checked: !!this.state.form.school.allowed,
                          value: !!this.state.form.school.allowed,
                          toggle: true,
                          className: ''
                        },
                        {
                          field: 'BooleanField',
                          topLabel: 'Allowed Home?',
                          label: 'Can Send Invites to Home?',
                          name: 'school.allowed_home',
                          wrapperClass: 'col-lg form-group',
                          checked: !!this.state.form.school.allowed_home,
                          value: !!this.state.form.school.allowed_home,
                          toggle: true,
                          className: ''
                        },
                        {
                          field: 'BooleanField',
                          topLabel: 'Closed?',
                          label: 'School Has Closed?',
                          name: 'school.closed',
                          wrapperClass: 'col-lg form-group',
                          checked: !!this.state.form.school.closed,
                          value: !!this.state.form.school.closed,
                          toggle: true,
                          className: ''
                        },
                      ]
                    },
                    {
                      field: 'hr',
                    },
                    {
                      field: 'AddressSection',
                      className: '',
                      label: 'Address',
                      name: `school.address_attributes`,
                      valuePrefix: `school.address_attributes`,
                      delegatedChange: true,
                      values: this.state.form.school.address_attributes,
                      required: true,
                      inline: true
                    },
                    {
                      field: 'hr',
                    },
                    {
                      field: 'TextField',
                      wrapperClass: `form-group ${this.state.form.school.reassign_athletes_validated ? 'was-validated' : ''}`,
                      label: 'Reassign Athletes',
                      name: 'school.reassign_athletes',
                      type: 'text',
                      value: this.state.form.school.reassign_athletes,
                      onChange: true,
                      required: false,
                      autoComplete: 'off',
                    },
                    {
                      field: 'hr',
                    },
                    {
                      field: 'button',
                      className: 'btn btn-danger btn-lg',
                      type: 'cancel',
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
