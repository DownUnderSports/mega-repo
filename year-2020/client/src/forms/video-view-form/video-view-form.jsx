import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';


export default class VideoViewForm extends Component {
  constructor(props) {
    super(props)

    const view = {
      video_id: '',
      watched: false,
      duration: '00:00:00'
    }

    const { changes } = Objected.existingOnly(view, props.view)

    this.state = {
      errors: null,
      changed: false,
      form: {
        view: {
          ...view,
          ...changes
        },
      }
    }

    this.action = `${this.props.url || '/admin/users'}/${this.props.userId}/video_views/${this.props.id || ''}`
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
          className='view-form mb-3'
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
                  form='view'
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
                          field: 'VideoSelectField',
                          onChange: true,
                          viewProps: {
                            className: 'form-control',
                            autoComplete: 'off',
                            required: !!this.state.form.view.watched,
                          },
                          wrapperClass: `col-12 form-group`,
                          label: 'Select Video',
                          name: 'view.video_id',
                          value: this.state.form.view.video_id,
                          autoCompleteKey: 'label',
                          valueKey: 'value'
                        },
                        {
                          field: 'BooleanField',
                          topLabel: 'Did Watch?',
                          label: 'Watched?',
                          name: 'view.watched',
                          wrapperClass: 'col-12 form-group',
                          checked: !!this.state.form.view.watched,
                          value: !!this.state.form.view.watched,
                          toggle: true,
                          className: ''
                        },
                        ...(this.state.form.view.watched ? [
                          {
                            field: 'TextField',
                            wrapperClass: `col-12 form-group ${this.state.form.view.duration_validated ? 'was-validated' : ''}`,
                            label: 'Watched Duration',
                            name: 'view.duration',
                            type: 'text',
                            value: this.state.form.view.duration,
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
