import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';


export default class MessageForm extends Component {
  constructor(props) {
    super(props)

    const message = {
      category: '',
      reason: '',
      message: false,
    }

    const { changes } = Objected.existingOnly(message, props.message)

    this.state = {
      errors: null,
      changed: false,
      categories: props.categories || [],
      reasons: props.reasons || [],
      form: {
        message: {
          ...message,
          ...changes
        },
      }
    }

    this.action = `${this.props.url || '/admin/users'}/${this.props.userId}/messages/${this.props.id || ''}?type=${props.type}`
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
      const result = await fetch(this.action, {
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
          className='message-form mb-3'
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
                  form='message'
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
                          field: 'SelectField',
                          onChange: true,
                          valueKey: 'value',
                          viewProps: {
                            className: 'form-control',
                            autoComplete: 'off',
                            required: true,
                          },
                          wrapperClass: `col-6 form-group`,
                          label: 'Category',
                          name: 'message.category',
                          options: this.state.categories,
                          value: this.state.form.message.category
                        },
                        {
                          field: 'SelectField',
                          onChange: true,
                          valueKey: 'value',
                          viewProps: {
                            className: 'form-control',
                            autoComplete: 'off',
                            required: true,
                          },
                          wrapperClass: `col-6 form-group`,
                          label: 'Reason',
                          name: 'message.reason',
                          options: this.state.reasons,
                          value: this.state.form.message.reason
                        },
                        {
                          field: 'TextAreaField',
                          label: 'Message',
                          name: 'message.message',
                          wrapperClass: 'col-12 form-group',
                          value: this.state.form.message.message,
                          className: 'form-control',
                          onChange: true
                        },
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
