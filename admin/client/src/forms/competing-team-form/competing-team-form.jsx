import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';

const competingTeam = {
        id:       "",
        name:     "",
        letter:   "",
        sport_id: "",
      }

export default class CompetingTeamForm extends Component {
  constructor(props) {
    super(props)

    const { changes } = Objected.existingOnly(competingTeam, props.competingTeam)

    this.state = {
      autoComplete: `false ${new Date()}`,
      errors: null,
      changed: false,
      form: {
        competing_team: {
          ...competingTeam,
          ...changes
        },
      }
    }

    this.action = `${
      this.props.url
      || '/admin/traveling/ground_control/competing_teams'
    }/${
      String(this.state.form.competing_team.id || '').replace(/new/i, '')
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
    this.setState({
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
        method: form.competing_team.id ? 'PATCH' : 'POST',
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
          className='competing_team-form mb-3'
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
                  form='competing_team'
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
                          wrapperClass: `col-md-4 form-group ${this.state.form.competing_team.letter_validated ? 'was-validated' : ''}`,
                          label: 'Competing Team Letter',
                          name: 'competing_team.letter',
                          type: 'text',
                          value: this.state.form.competing_team.letter || '',
                          onChange: true,
                          autoComplete: this.state.autoComplete,
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-md-4 form-group ${this.state.form.competing_team.name_validated ? 'was-validated' : ''}`,
                          label: 'Competing Team Name',
                          name: 'competing_team.name',
                          type: 'text',
                          value: this.state.form.competing_team.name || '',
                          onChange: true,
                          autoComplete: this.state.autoComplete,
                          required: true
                        },
                        {
                          field: 'SportSelectField',
                          wrapperClass: `col-md-4 form-group ${this.state.form.competing_team.sport_id_validated ? 'was-validated' : ''}`,
                          label: 'Sport',
                          name: 'competing_team.sport_id',
                          value: this.state.form.competing_team.sport_id || '',
                          onChange: true,
                          autoCompleteKey: 'label',
                          valueKey: 'value',
                          viewProps: {
                            className: 'form-control',
                            autoComplete: this.state.autoComplete,
                            required: false,
                          },
                        },
                      ]
                    },
                    {
                      field: 'hr',
                    },
                    ...(
                        !this.state.form.competing_team.id ? [] : [
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
