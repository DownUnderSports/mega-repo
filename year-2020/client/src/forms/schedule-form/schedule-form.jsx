import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';

const schedule = {
        id: '',
        pnr: '',
        carrier_pnr: '',
        operator: '',
        parent_schedule_id: '',
        amount: '',
        seats_reserved: 0,
        names_assigned: 0,
        booking_reference: '',
        rtaxr: '',
        legs_attributes: [
          {
            id: '',
            flight_number: '',
            departing_airport_code: '',
            local_departing_at: '',
            arriving_airport_code: '',
            local_arriving_at: '',
            is_subsidiary: false,
            _destroy: false
          }
        ]
      }

export default class ScheduleForm extends Component {
  constructor(props) {
    super(props)

    const { changes } = Objected.existingOnly(schedule, props.schedule)

    if(Object.isObject(changes.amount)) changes.amount = currencyFormat(changes.amount.decimal)

    this.state = {
      errors: null,
      changed: false,
      form: {
        flight_schedule: {
          ...schedule,
          ...changes
        },
      },
      autoComplete: new Date().toString()
    }

    this.action = `${
      this.props.url
      || '/admin/traveling/flights/schedules'
    }/${
      String(this.state.form.flight_schedule.id || '').replace(/new/i, '')
    }`
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const target = ev.currentTarget
    let start, end
    try {
      if(target.type === "text") {
        start = target.selectionStart
        end = target.selectionEnd
      }
    } catch(_) {}

    const v = ev ? (formatter ? this[formatter](target.value) : target.value) : formatter

    return onFormChange(this, k, v, true, () => {
      try {
        if(target.type === "text") target.setSelectionRange(start, end)
      } catch(_) {}
      cb()
    })
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
    if((e.keyCode === 13) && e.ctrlKey) this.onSubmit(e)
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

      const result =  await fetch(this.action, {
        method: form.flight_schedule.id ? 'PATCH' : 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify(form)
      });

      const { id = 'new' } = await result.json()

      this.props.onSuccess && this.props.onSuccess(id)
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
        message='SUBMITTING...'
        loadingElement={
          <JellyBox className="page-loader" />
        }
      >
        <form
          action={this.action}
          method='post'
          className='schedule-form mb-3'
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
            <div className='m-0'>
              <DisplayOrLoading display={!this.state.checkingId}>
                <FieldsFromJson
                  onChange={this.onChange}
                  form='schedule'
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
                          field: 'TextAreaField',
                          wrapperClass: `col-12 form-group ${this.state.form.flight_schedule.original_value_validated ? 'was-validated' : ''}`,
                          label: 'Paste Schedule from Amadeus',
                          name: 'flight_schedule.original_value',
                          type: 'text',
                          value: this.state.form.flight_schedule.original_value || '',
                          onChange: true,
                          autoComplete: `false ${this.state.autoComplete}`,
                          rows: 5,
                          required: false
                        },
                        ...(
                          this.state.form.flight_schedule.original_value ? [] : [
                            {
                              field: 'TextField',
                              wrapperClass: `col-md-3 form-group ${this.state.form.flight_schedule.pnr_validated ? 'was-validated' : ''}`,
                              label: 'Amadeus PNR',
                              name: 'flight_schedule.pnr',
                              type: 'text',
                              value: this.state.form.flight_schedule.pnr || '',
                              onChange: true,
                              formatter: 'upcaseValue',
                              autoComplete: `false ${this.state.autoComplete}`,
                              looseCasing: 'toUpperCase',
                              required: false
                            },
                            {
                              field: 'TextField',
                              wrapperClass: `col-md-3 form-group ${this.state.form.flight_schedule.carrier_pnr_validated ? 'was-validated' : ''}`,
                              label: 'Carrier PNR',
                              name: 'flight_schedule.carrier_pnr',
                              type: 'text',
                              value: this.state.form.flight_schedule.carrier_pnr || '',
                              onChange: true,
                              formatter: 'upcaseValue',
                              autoComplete: `false ${this.state.autoComplete}`,
                              required: false
                            },
                            {
                              field: 'TextField',
                              wrapperClass: `col-md-3 form-group ${this.state.form.flight_schedule.booking_reference_validated ? 'was-validated' : ''}`,
                              label: 'Booking Reference',
                              name: 'flight_schedule.booking_reference',
                              type: 'text',
                              value: this.state.form.flight_schedule.booking_reference || '',
                              onChange: true,
                              autoComplete: `false ${this.state.autoComplete}`,
                              required: false
                            },
                            {
                              field: 'SelectField',
                              wrapperClass: `col-md-3 form-group ${this.state.form.flight_schedule.operator_validated ? 'was-validated' : ''}`,
                              label: `Operator`,
                              name: 'flight_schedule.operator',
                              value: this.state.form.flight_schedule.operator || '',
                              onChange: true,
                              autoComplete: `false ${this.state.autoComplete}`,
                              required: true,
                              options: [
                                "",
                                "Air Canada",
                                "American Airlines",
                                "Delta",
                                "Hawaiian Air",
                                "JetStar",
                                "Qantas",
                                "United Airlines",
                                "Virgin Australia",
                                "CLIENT BOOKED"
                              ],
                              valueKey: 'value',
                              viewProps: {
                                className:'form-control',
                              },
                            },
                            {
                              field: 'TextField',
                              wrapperClass: `col-md-4 form-group ${this.state.form.flight_schedule.amount_validated ? 'was-validated' : ''}`,
                              label: "Schedule Price",
                              name: 'flight_schedule.amount',
                              type: 'text',
                              inputMode: 'numeric',
                              value: this.state.form.flight_schedule.amount || '',
                              useCurrencyFormat: true,
                              onChange: true,
                              autoComplete: `false ${this.state.autoComplete}`,
                              placeholder: '(0.00)',
                              required: true
                            },
                            {
                              field: 'TextField',
                              wrapperClass: `col-md-4 form-group ${this.state.form.flight_schedule.seats_reserved_validated ? 'was-validated' : ''}`,
                              label: 'Seats Reserved',
                              name: 'flight_schedule.seats_reserved',
                              type: 'text',
                              inputMode: 'numeric',
                              value: this.state.form.flight_schedule.seats_reserved || 0,
                              pattern: '[0-9]+',
                              onChange: true,
                              autoComplete: `false ${this.state.autoComplete}`,
                              required: true
                            },
                            {
                              field: 'TextField',
                              wrapperClass: `col-md-4 form-group ${this.state.form.flight_schedule.names_assigned_validated ? 'was-validated' : ''}`,
                              label: 'Names Assigned',
                              name: 'flight_schedule.names_assigned',
                              type: 'text',
                              inputMode: 'numeric',
                              value: this.state.form.flight_schedule.names_assigned || 0,
                              pattern: '[0-9]+',
                              onChange: true,
                              autoComplete: `false ${this.state.autoComplete}`,
                              required: true
                            },
                            {
                              field: 'TextAreaField',
                              wrapperClass: `col-12 form-group ${this.state.form.flight_schedule.rtaxr_validated ? 'was-validated' : ''}`,
                              label: 'Paste RTAXR from Amadeus if Subschedule',
                              name: 'flight_schedule.rtaxr',
                              type: 'text',
                              value: this.state.form.flight_schedule.rtaxr || '',
                              rows: 5,
                              onChange: true,
                              autoComplete: `false ${this.state.autoComplete}`,
                              required: false
                            },
                            {
                              className: 'col-12',
                              fields: [
                                {
                                  field: 'table',
                                  className: 'table',
                                  fields: [
                                    {
                                      field: 'thead',
                                      fields: [
                                        {
                                          field: 'tr',
                                          fields: [
                                            {
                                              field: 'th',
                                              children: [
                                                'Flight Number'
                                              ]
                                            },
                                            {
                                              field: 'th',
                                              children: [
                                                'Departing From'
                                              ]
                                            },
                                            {
                                              field: 'th',
                                              children: [
                                                'Arriving To'
                                              ]
                                            },
                                            {
                                              field: 'th',
                                              children: [
                                                'Departing Time (Local)'
                                              ]
                                            },
                                            {
                                              field: 'th',
                                              children: [
                                                'Arriving Time (Local)'
                                              ]
                                            },
                                            {
                                              field: 'th',
                                              children: [
                                                'Is Subsidiary?'
                                              ]
                                            },
                                            {
                                              field: 'th',
                                              children: [
                                                'Delete Leg?'
                                              ]
                                            },
                                          ]
                                        }
                                      ]
                                    },
                                    {
                                      field: 'tbody',
                                      fields: (this.state.form.flight_schedule.legs_attributes || []).map((v, i) => ({
                                        field: 'tr',
                                        fields: [
                                          {
                                            field: 'td',
                                            className: `${v.flight_number_validated ? 'was-validated' : ''}`,
                                            fields: [
                                              {
                                                field: 'TextField',
                                                skipExtras: true,
                                                label: 'Flight Number',
                                                name: `flight_schedule.legs_attributes.${i}.flight_number`,
                                                type: 'text',
                                                value: v.flight_number || '',
                                                onChange: true,
                                                autoComplete: `false ${this.state.autoComplete}`,
                                                placeholder: '(QF 15)',
                                                required: false
                                              },
                                            ]
                                          },
                                          {
                                            field: 'td',
                                            className: `${v.departing_airport_code_validated ? 'was-validated' : ''}`,
                                            fields: [
                                              {
                                                field: 'TextField',
                                                skipExtras: true,
                                                label: 'Departing From',
                                                name: `flight_schedule.legs_attributes.${i}.departing_airport_code`,
                                                type: 'text',
                                                value: v.departing_airport_code || '',
                                                onChange: true,
                                                autoComplete: `false ${this.state.autoComplete}`,
                                                placeholder: '(LAX)',
                                                pattern: '[A-Z]{3}',
                                                formatter: 'upcaseValue',
                                                required: !!v.flight_number
                                              },
                                            ]
                                          },
                                          {
                                            field: 'td',
                                            className: `${v.arriving_airport_code_validated ? 'was-validated' : ''}`,
                                            fields: [
                                              {
                                                field: 'TextField',
                                                skipExtras: true,
                                                label: 'Arriving To',
                                                name: `flight_schedule.legs_attributes.${i}.arriving_airport_code`,
                                                type: 'text',
                                                value: v.arriving_airport_code || '',
                                                onChange: true,
                                                autoComplete: `false ${this.state.autoComplete}`,
                                                placeholder: '(LAX)',
                                                pattern: '[A-Z]{3}',
                                                formatter: 'upcaseValue',
                                                required: !!v.flight_number
                                              },
                                            ]
                                          },
                                          {
                                            field: 'td',
                                            className: `${v.local_departing_at_validated ? 'was-validated' : ''}`,
                                            fields: [
                                              {
                                                field: 'TextField',
                                                skipExtras: true,
                                                label: 'Departing Time (Local)',
                                                name: `flight_schedule.legs_attributes.${i}.local_departing_at`,
                                                type: 'text',
                                                value: v.local_departing_at || '',
                                                onChange: true,
                                                autoComplete: `false ${this.state.autoComplete}`,
                                                placeholder: 'YYYY-MM-DD HH:MM (A|P)M',
                                                pattern: '\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2} (A|P)M',
                                                formatter: 'upcaseValue',
                                                required: !!v.flight_number
                                              },
                                            ]
                                          },
                                          {
                                            field: 'td',
                                            className: `${v.local_arriving_at_validated ? 'was-validated' : ''}`,
                                            fields: [
                                              {
                                                field: 'TextField',
                                                skipExtras: true,
                                                label: 'Arriving Time (Local)',
                                                name: `flight_schedule.legs_attributes.${i}.local_arriving_at`,
                                                type: 'text',
                                                value: v.local_arriving_at || '',
                                                onChange: true,
                                                autoComplete: `false ${this.state.autoComplete}`,
                                                placeholder: 'YYYY-MM-DD HH:MM (A|P)M',
                                                pattern: '\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2} (A|P)M',
                                                formatter: 'upcaseValue',
                                                required: !!v.flight_number
                                              },
                                            ]
                                          },
                                          {
                                            field: 'td',
                                            fields: [
                                              {
                                                field: 'BooleanField',
                                                skipTopLabel: true,
                                                label: 'Is Subsidiary?',
                                                name: `flight_schedule.legs_attributes.${i}.is_subsidiary`,
                                                type: 'text',
                                                value: !!v.is_subsidiary,
                                                checked: !!v.is_subsidiary,
                                                toggle: true,
                                                autoComplete: `false ${this.state.autoComplete}`,
                                                className: ''
                                              },
                                            ]
                                          },
                                          {
                                            field: 'td',
                                            fields: v.id ? [
                                              {
                                                field: 'BooleanField',
                                                skipTopLabel: true,
                                                label: 'Remove?',
                                                name: `flight_schedule.legs_attributes.${i}._destroy`,
                                                type: 'text',
                                                value: !!v._destroy,
                                                checked: !!v._destroy,
                                                toggle: true,
                                                autoComplete: `false ${this.state.autoComplete}`,
                                                className: ''
                                              },
                                            ] : []
                                          },
                                        ]
                                      }))
                                    }
                                  ]
                                }
                              ]
                            }
                          ]
                        )
                      ]
                    },
                    {
                      field: 'hr',
                    },
                    ...(
                      (
                        !this.state.form.flight_schedule.id
                        || this.state.form.flight_schedule.original_value
                      ) ? [] : [
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
