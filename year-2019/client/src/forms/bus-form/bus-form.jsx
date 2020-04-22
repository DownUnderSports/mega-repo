import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';

const bus = {
        id:       "",
        combo:    "",
        hotel_id: "",
        sport_id: "",
        details: '',
      }

export default class BusForm extends Component {
  constructor(props) {
    super(props)

    const { changes } = Objected.existingOnly(bus, props.bus)

    this.state = {
      autoComplete: `false ${new Date()}`,
      errors: null,
      changed: false,
      form: {
        bus: {
          ...bus,
          ...changes
        },
      }
    }

    this.action = `${
      this.props.url
      || '/admin/traveling/ground_control/buses'
    }/${
      String(this.state.form.bus.id || '').replace(/new/i, '')
    }`
  }

  componentDidUpdate(prevProps) {
    const propsDidChange = Objected.existingOnly(prevProps.bus, this.props.bus).changed

    console.log(propsDidChange)

    if(propsDidChange) {
      const { changes } = Objected.existingOnly(bus, this.props.bus)

      this.setState({
        changed: false,
        form: {
          bus: {
            ...bus,
            ...changes
          }
        }
      })
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

  onFormKeyDown = (e) => {
    if((e.keyCode === 13) && e.ctrlKey) this.onSubmit(e)
  }

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({
      errors: null,
      submitting: true,
      autoComplete: `false ${new Date()}`,
    })
    this.handleSubmit()
  }

  handleSubmit = async () => {
    if(!this.state.changed) return this.props.onSuccess()
    try {
      const form = deleteValidationKeys(
        Objected.deepClone(
          this.state.form
        )
      )

      const result =  await fetch(this.action, {
        method: form.bus.id ? 'PATCH' : 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify(form)
      });

      const { id = 'new' } = await result.json()

      this.setState({ submitting: false }, () => {
        this.props.onSuccess && this.props.onSuccess(id)
      })
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
          className='bus-form mb-3'
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
                  form='bus'
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
                          field: 'SelectField',
                          wrapperClass: `col-md-4 form-group ${this.state.form.bus.combo_validated ? 'was-validated' : ''}`,
                          label: `Name/Color Combo`,
                          name: 'bus.combo',
                          value: this.state.form.bus.combo || '',
                          onChange: true,
                          autoComplete: this.state.autoComplete,
                          required: true,
                          options: [
                            { value: "", label: '-- Color Combo --' },
                            ...(this.props.colors || [])
                          ],
                          valueKey: 'value',
                          viewProps: {
                            className:'form-control',
                          },
                        },
                        {
                          field: 'SportSelectField',
                          wrapperClass: `col-md-4 form-group ${this.state.form.bus.sport_id_validated ? 'was-validated' : ''}`,
                          label: 'Sport',
                          name: 'bus.sport_id',
                          value: this.state.form.bus.sport_id || '',
                          onChange: true,
                          autoCompleteKey: 'label',
                          valueKey: 'value',
                          viewProps: {
                            className: 'form-control',
                            autoComplete: this.state.autoComplete,
                            required: false,
                          },
                        },
                        {
                          field: 'HotelSelectField',
                          wrapperClass: `col-md-4 form-group ${this.state.form.bus.hotel_id_validated ? 'was-validated' : ''}`,
                          label: 'Hotel',
                          name: 'bus.hotel_id',
                          value: this.state.form.bus.hotel_id || '',
                          onChange: true,
                          autoCompleteKey: 'label',
                          valueKey: 'value',
                          viewProps: {
                            className: 'form-control',
                            autoComplete: this.state.autoComplete,
                            required: false,
                          },
                        },
                        {
                          field: 'TextAreaField',
                          wrapperClass: `col-12 form-group ${this.state.form.bus.details_validated ? 'was-validated' : ''}`,
                          label: 'Bus Details',
                          name: 'bus.details',
                          type: 'text',
                          value: this.state.form.bus.details || '',
                          onChange: true,
                          autoComplete: this.state.autoComplete,
                          rows: 5,
                          required: false
                        },
                      ]
                    },
                    {
                      field: 'hr',
                    },
                    ...(
                        !this.state.form.bus.id ? [] : [
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
