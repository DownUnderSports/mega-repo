import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';

const eventResult = {
        id:         "",
        name:       "",
        sport_id:   "",
      }

export default class EventResultForm extends Component {
  constructor(props) {
    super(props)

    const { changes } = Objected.existingOnly(eventResult, props.eventResult),
           autoCompleteDate = +(new Date())

    this.state = {
      autoCompleteDate,
      autoComplete: `false ${autoCompleteDate}`,
      errors: null,
      changed: false,
      form: {
        event_result: {
          ...eventResult,
          ...changes
        },
      }
    }

    this.action = `${
      this.props.url
      || '/admin/traveling/event_results'
    }/${
      String(this.state.form.event_result.id || '').replace(/new/i, '')
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
    if((e.keyCode === 13) && e.ctrlKey) this.onSubmit(e)
  }

  onSubmit = (e) => {
    e.preventDefault();
    const autoCompleteDate = +(new Date())
    this.setState({
      submitting: true,
      autoCompleteDate,
      errors: null,
      autoComplete: `false ${autoCompleteDate}`,
    }, this.handleSubmit)
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
        method: form.event_result.id ? 'PATCH' : 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify(form)
      });

      const { id = 'new' } = await result.json()

      this.props.onSuccess ? this.props.onSuccess(id) : this.setState({ submitting: false })
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
          id={`ev_res_form_${this.state.autoCompleteDate}`}
          action={this.action}
          method='post'
          className='event_result-form mb-3'
          onSubmit={this.onSubmit}
          onKeyDown={this.onFormKeyDown}
          autoComplete="off"
        >
        </form>
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
                form='event_result'
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
                            form: `ev_res_form_${this.state.autoCompleteDate}`,
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
                        wrapperClass: `col-md-4 form-group ${this.state.form.event_result.name_validated ? 'was-validated' : ''}`,
                        label: 'Result Name',
                        name: 'event_result.name',
                        type: 'text',
                        value: this.state.form.event_result.name || '',
                        onChange: true,
                        autoComplete: this.state.autoComplete,
                        form: `ev_res_form_${this.state.autoCompleteDate}`,
                        required: true
                      },
                      {
                        field: 'SportSelectField',
                        wrapperClass: `col-md-4 form-group ${this.state.form.event_result.sport_id_validated ? 'was-validated' : ''}`,
                        label: 'Sport',
                        name: 'event_result.sport_id',
                        value: this.state.form.event_result.sport_id || '',
                        onChange: true,
                        autoCompleteKey: 'label',
                        valueKey: 'value',
                        form: `ev_res_form_${this.state.autoCompleteDate}`,
                        viewProps: {
                          form: `ev_res_form_${this.state.autoCompleteDate}`,
                          className: 'form-control',
                          autoComplete: this.state.autoComplete,
                          required: true,
                        },
                      },
                    ]
                  },
                  {
                    field: 'hr',
                  },
                  ...(
                      !this.state.form.event_result.id ? [] : [
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
                      },
                      {
                        field: 'h3',
                        children: 'Broadcast Results'
                      },
                      {
                        field: 'TextField',
                        wrapperClass: `col-12 form-group ${this.state.form.event_result.subject_validated ? 'was-validated' : ''}`,
                        label: 'Email Subject/Title',
                        name: 'event_result.subject',
                        type: 'text',
                        value: this.state.form.event_result.subject || '',
                        onChange: true,
                        autoComplete: this.state.autoComplete,
                        form: `ev_res_form_${this.state.autoCompleteDate}`,
                      },
                      {
                        field: 'TextAreaField',
                        wrapperClass: `col-12 form-group ${this.state.form.event_result.description_validated ? 'was-validated' : ''}`,
                        label: 'Email Body',
                        name: 'event_result.description',
                        type: 'text',
                        value: this.state.form.event_result.description || '',
                        onChange: true,
                        autoComplete: this.state.autoComplete,
                        form: `ev_res_form_${this.state.autoCompleteDate}`,
                        feedback: 'The body of the Broadcast Email',
                      },
                      {
                        field: 'TextField',
                        wrapperClass: `col-12 form-group ${this.state.form.event_result.email_validated ? 'was-validated' : ''}`,
                        label: 'Email Override (optional)',
                        name: 'event_result.email',
                        type: 'text',
                        value: this.state.form.event_result.email || '',
                        onChange: true,
                        autoComplete: this.state.autoComplete,
                        feedback: 'Semi-Colon Separated. Send to this email instead of the whole team.',
                        form: `ev_res_form_${this.state.autoCompleteDate}`,
                      },
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
                    form: `ev_res_form_${this.state.autoCompleteDate}`,
                    children: [
                      'Submit'
                    ]
                  }
                ]}
              />
            </DisplayOrLoading>
          </div>
        </section>
      </DisplayOrLoading>
    )
  }
}
