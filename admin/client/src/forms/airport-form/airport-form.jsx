import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';

const codePattern = '[A-Z]{3}',
      codeRegex = new RegExp(codePattern),
      airport = {
        id: '',
        code: '',
        name: '',
        carrier: '',
        cost: '',
        tz_offset: 0,
        dst: true,
        preferred: false,
        selectable: false,
        location_override: '',
        track_departing_date: '',
        track_returning_date: '',
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

export default class AirportForm extends Component {
  constructor(props) {
    super(props)

    const { changes } = Objected.existingOnly(airport, props.airport)

    if(Object.isObject(changes.cost)) changes.cost = currencyFormat(changes.cost.decimal)
    if(changes.tz_offset) changes.tz_offset = this.secondsToHours(changes.tz_offset)

    this.state = {
      errors: null,
      changed: false,
      form: {
        airport: {
          ...airport,
          ...changes
        },
      },
      autoComplete: new Date().toString(),
    }

    this.action = `${
      this.props.url
      || '/admin/traveling/flights/airports'
    }/${
      String(this.state.form.airport.id || '').replace(/new/i, '')
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

  downcaseValue(v) {
    return String(v).toLowerCase()
  }

  upcaseValue(v) {
    return String(v).toUpperCase()
  }

  secondsToHours(s) {
    return (Math.abs(s = +s) > 20) ? (s / (60 * 60)) : s
  }


  onFormKeyDown = (e) => {
    if(e.ctrlKey && (e.key === "Enter")) this.onSubmit(e)
  }

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({submitting: true})
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

      if(!form.airport.address_attributes.street) {
        delete form.airport.address_attributes
      }

      const result =  await fetch(this.action, {
        method: form.airport.id ? 'PATCH' : 'POST',
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
    return window.document.title === 'Home Page' ? 'Above User' : window.document.title
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
          className='airport-form mb-3'
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
                  form='airport'
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
                          wrapperClass: `col-lg-12 form-group ${this.state.form.airport.name_validated ? 'was-validated' : ''}`,
                          label: 'Name',
                          placeholder: '(Salt Lake City International Airport)',
                          name: 'airport.name',
                          type: 'text',
                          value: this.state.form.airport.name || '',
                          onChange: true,
                          required: true,
                          autoComplete: `false ${this.state.autoComplete}`,
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-1 form-group ${this.state.form.airport.code_validated ? 'was-validated' : ''}`,
                          label: '3-Letter Code',
                          placeholder: '(SLC)',
                          pattern: codePattern,
                          name: 'airport.code',
                          type: 'text',
                          value: this.state.form.airport.code || '',
                          onChange: true,
                          formatter: 'upcaseValue',
                          autoComplete: `false ${this.state.autoComplete}`,
                          looseCasing: 'toUpperCase',
                          feedback: (
                            <span className={`${codeRegex.test(this.state.form.airport.code) ? 'd-none' : 'text-danger'}`}>
                              Please enter a valid airport code
                            </span>
                          ),
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-3 form-group ${this.state.form.airport.carrier_validated ? 'was-validated' : ''}`,
                          pattern: '[a-z ]+',
                          formatter: 'downcaseValue',
                          label: 'Carrier',
                          placeholder: '(qantas)',
                          name: 'airport.carrier',
                          type: 'text',
                          value: this.state.form.airport.carrier || '',
                          onChange: true,
                          autoComplete: `false ${this.state.autoComplete}`,
                          looseCasing: 'toLowerCase',
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-2 form-group ${this.state.form.airport.cost_validated ? 'was-validated' : ''}`,
                          label: `Airport Cost (Round-Trip)`,
                          name: 'airport.cost',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.airport.cost || '',
                          useCurrencyFormat: true,
                          onChange: true,
                          autoComplete: `false ${this.state.autoComplete}`,
                          placeholder: '(374.00)',
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-3 form-group ${this.state.form.airport.tz_offset_validated ? 'was-validated' : ''}`,
                          pattern: '-?[0-9]+',
                          label: `Time Zone Offset (Hours)`,
                          name: 'airport.tz_offset',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.airport.tz_offset || '',
                          onChange: true,
                          autoComplete: `false ${this.state.autoComplete}`,
                          placeholder: '(-7)',
                          required: true
                        },
                        {
                          field: 'BooleanField',
                          topLabel: 'Observes DST?',
                          label: 'Observes DST?',
                          name: `airport.dst`,
                          wrapperClass: "col-lg-3 form-group",
                          checked: !!this.state.form.airport.dst,
                          value: !!this.state.form.airport.dst,
                          toggle: true,
                          className: ''
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-lg-12 form-group ${this.state.form.airport.location_override_validated ? 'was-validated' : ''}`,
                          label: `Override Location on Travel Card`,
                          name: 'airport.location_override',
                          type: 'text',
                          value: this.state.form.airport.location_override || '',
                          onChange: true,
                          formatter: 'upcaseValue',
                          autoComplete: `false ${this.state.autoComplete}`,
                          looseCasing: 'toUpperCase',
                          placeholder: 'BRISBANE, QLD',
                          required: false
                        },
                        {
                          field: 'CalendarField',
                          wrapperClass: `col-md form-group ${this.state.form.airport.track_departing_date_validated ? 'was-validated' : ''}`,
                          label: "Track Departing Date",
                          name: 'airport.track_departing_date',
                          type: 'text',
                          value: this.state.form.airport.track_departing_date,
                          valueKey: 'value',
                          placeholder: '2020-07-04',
                          pattern: "\\d{4}-\\d{2}-\\d{2}",
                          onChange: true,
                          closeOnSelect: true,
                          autoComplete: `false ${this.state.autoComplete}`,
                        },
                        {
                          field: 'CalendarField',
                          wrapperClass: `col-md form-group ${this.state.form.airport.track_returning_date_validated ? 'was-validated' : ''}`,
                          label: "Track Returning Date",
                          name: 'airport.track_returning_date',
                          type: 'text',
                          value: this.state.form.airport.track_returning_date,
                          valueKey: 'value',
                          placeholder: '2020-07-13',
                          pattern: "\\d{4}-\\d{2}-\\d{2}",
                          onChange: true,
                          closeOnSelect: true,
                          autoComplete: `false ${this.state.autoComplete}`,
                        },
                        // {
                        //   field: 'BooleanField',
                        //   label: 'Selectable?',
                        //   name: `airport.selectable`,
                        //   wrapperClass: "col-lg-6 form-group",
                        //   checked: !!this.state.form.airport.selectable,
                        //   value: !!this.state.form.airport.selectable,
                        //   toggle: true,
                        //   className: ''
                        // },
                        // {
                        //   field: 'BooleanField',
                        //   label: 'Preferred?',
                        //   name: `airport.preferred`,
                        //   wrapperClass: "col-lg-6 form-group",
                        //   checked: !!this.state.form.airport.preferred,
                        //   value: !!this.state.form.airport.preferred,
                        //   toggle: true,
                        //   className: ''
                        // },
                      ]
                    },
                    {
                      field: 'AddressSection',
                      className: '',
                      label: 'Address',
                      name: `airport.address_attributes`,
                      valuePrefix: `airport.address_attributes`,
                      delegatedChange: true,
                      values: this.state.form.airport.address_attributes,
                      required: false,
                      inline: true
                    },
                    {
                      field: 'hr',
                    },
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
