import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';

const hotel = {
        id:         '',
        name:       '',
        phone:      '',
        contacts:   [],
        address_attributes: {
          is_foreign: '',
          street: '',
          street_2: '',
          street_3: '',
          city: '',
          state_id: '',
          province: '',
          zip: '',
          country: '',
        }
      }

export default class HotelForm extends Component {
  constructor(props) {
    super(props)

    const { changes } = Objected.existingOnly(hotel, props.hotel)

    this.state = {
      errors: null,
      changed: false,
      autoComplete: `false ${new Date()}`,
      form: {
        hotel: {
          ...hotel,
          ...changes
        },
      }
    }

    this.action = `${
      this.props.url
      || '/admin/traveling/ground_control/hotels'
    }/${
      String(this.state.form.hotel.id || '').replace(/new/i, '')
    }`
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
    if(e.ctrlKey && (e.key === "Enter")) this.onSubmit(e)
  }

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({ submitting: true, autoComplete: `false ${new Date()}` })
    this.handleSubmit()
  }

  deleteNewIDs = (object) => {
    if(!object.id || /new/i.test(String(object.id))) {
      delete object.id
    }

    for (let k in object) {
      if(Object.isPureObject(object[k])) {
        this.deleteNewIDs(object[k])
      } else if(Array.isArray(object[k])) {
        for (var i = 0; i < object[k].length; i++) {
          let v = object[k][i]
          if(Object.isPureObject(v)) this.deleteNewIDs(v)
        }
      }
    }

    return object
  }

  handleSubmit = async () => {
    if(!this.state.changed) return this.props.onSuccess()
    try {
      const form = this.deleteNewIDs(
        deleteValidationKeys(
          Objected.deepClone(
            this.state.form
          )
        )
      )

      if(!form.hotel.address_attributes.street) {
        delete form.hotel.address_attributes
      }

      const result =  await fetch(this.action, {
        method: form.hotel.id ? 'PATCH' : 'POST',
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
          className='hotel-form mb-3'
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
                  form='hotel'
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
                              type: 'button',
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
                          field: 'TextField',
                          wrapperClass: `col-lg-6 form-group ${this.state.form.hotel.name_validated ? 'was-validated' : ''}`,
                          label: 'Name',
                          placeholder: '(Novatel)',
                          name: 'hotel.name',
                          type: 'text',
                          value: this.state.form.hotel.name || '',
                          onChange: true,
                          required: true,
                          autoComplete: this.state.autoComplete,
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-6 form-group ${this.state.form.hotel.phone_validated ? 'was-validated' : ''}`,
                          label: 'Phone Number',
                          name: 'hotel.phone',
                          placeholder: '(0400 123 456)',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.hotel.phone || '',
                          usePhoneFormat: true,
                          onChange: true,
                          autoComplete: this.state.autoComplete,
                        },
                      ]
                    },
                    {
                      field: 'AddressSection',
                      className: '',
                      label: 'Address',
                      name: `hotel.address_attributes`,
                      valuePrefix: `hotel.address_attributes`,
                      delegatedChange: true,
                      values: this.state.form.hotel.address_attributes,
                      required: false,
                      inline: true,
                      category: this.state.autoComplete
                    },
                    {
                      field: 'hr',
                    },
                    ...(
                        !this.state.form.hotel.id ? [] : [
                        {
                          className: 'row',
                          fields: [
                            {
                              className: 'col-12',
                              children: this.props.children
                            },
                          ]
                        },
                        {
                          field: 'hr'
                        }
                      ]
                    ),
                    {
                      field: 'button',
                      className: 'btn btn-danger btn-lg',
                      type: 'button',
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
