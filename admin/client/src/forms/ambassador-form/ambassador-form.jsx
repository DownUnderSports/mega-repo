import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';

export default class AmbassadorForm extends Component {
  constructor(props) {
    super(props)

    let ambassador = {
      ambassador_user_id: '',
      types_array: [],
    }

    const types = {
      email: false,
      phone: false
    }

    const { changes } = Objected.existingOnly(ambassador, props.ambassador)

    ambassador = {
      ...ambassador,
      ...changes
    }

    ambassador.types_array.map(t => types[t] = true)

    this.state = {
      errors: null,
      changed: false,
      form: {
        dus_id: '',
        ambassador,
        types
      }
    }

    this.action = `/admin/users/${this.props.userId}/ambassadors/${this.props.id || ''}`
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter
    console.log(k)

    return onFormChange(this, k, v, true, cb, (() => {}), /types\./)
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
    this.setState({submitting: true})
    this.handleSubmit()
  }

  handleSubmit = async (isDelete = false) => {
    isDelete = isDelete === "DELETE"
    if(!isDelete && !this.state.changed) return this.props.onSuccess()
    try {
      let form = {}, method = "DELETE", phone
      if(!isDelete) {
        method = this.props.id ? 'PATCH' : 'POST'
        form = deleteValidationKeys(Objected.deepClone(this.state.form))
        form.ambassador.types_array = []

        Object.keys(form.types).map(t => form.types[t] && form.ambassador.types_array.push(t))

        delete form.types
      }

      console.log(form, phone)

      const result = await fetch(this.action, {
        method,
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
        this.setState({errors: [ err.ambassador ], submitting: false})
      }
    }
  }

  onCancel = (e) => {
    e.preventDefault();
    e.stopPropagation();
    return this.props.onCancel && this.props.onCancel();
  }

  onDelete = (e) => {
    e.preventDefault();
    e.stopPropagation();
    return this.handleSubmit("DELETE");
  }

  render() {
    const { ambassador = {} } = this.props
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
          className='ambassador-form mb-3'
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
            {
              !!ambassador.first && (
                <header>
                  <h4>Set Ambassador Permissions for { ambassador.first } { ambassador.last } ({ ambassador.dus_id })</h4>
                  <hr/>
                </header>
              )
            }
            <FieldsFromJson
              onChange={this.onChange}
              form='ambassador'
              fields={[
                {
                  className: 'row',
                  fields: [
                    {
                      className: 'col mb-3',
                      fields: [
                        {
                          field: 'button',
                          className: 'btn btn-block btn-danger btn-lg',
                          type: 'button',
                          onClick: this.onCancel,
                          children: [
                            'Cancel'
                          ]
                        }
                      ]
                    },
                    {
                      className: 'col mb-3',
                      fields: [
                        {
                          field: 'button',
                          className: 'btn btn-block btn-warning btn-lg',
                          type: 'submit',
                          onClick: this.onDelete,
                          children: [
                            'DELETE'
                          ]
                        }
                      ]
                    },
                    {
                      className: 'col mb-3',
                      fields: [
                        {
                          field: 'button',
                          className: 'btn btn-block btn-primary btn-lg active',
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
                      field: 'TextField',
                      label: 'DUS ID',
                      name: 'dus_id',
                      wrapperClass: 'col-12 form-group',
                      value: this.state.form.dus_id,
                      className: 'form-control',
                      onChange: true,
                      required: !this.state.form.ambassador.ambassador_user_id,
                      placeholder: this.state.form.ambassador.ambassador_user_id ? '(Enter an ID to switch ambassador)' : 'DUS ID Required'
                    },
                    ...(
                      Object
                        .keys(this.state.form.types)
                        .map(t => ({
                          key: t,
                          field: 'BooleanField',
                          topLabel: `${t.capitalize()}?`,
                          label: `Is a(n) ${t.capitalize()} Ambassador?`,
                          name: `types.${t}`,
                          wrapperClass: 'col-lg form-group',
                          checked: !!this.state.form.types[t],
                          value: !!this.state.form.types[t],
                          toggle: true,
                          className: ''
                        }))
                    )
                  ]
                },
                {
                  field: 'button',
                  className: 'btn btn-danger btn-lg',
                  type: 'submit',
                  onClick: this.onCancel,
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
          </section>
        </form>
      </DisplayOrLoading>
    )
  }
}
