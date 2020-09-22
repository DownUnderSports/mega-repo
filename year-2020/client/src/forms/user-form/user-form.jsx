import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import dusIdFormat from 'common/js/helpers/dus-id-format'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';
import { userIsValid, baseErrorLink } from 'common/js/components/find-user';
import { allowBlankEmailRegex as emailRegex } from 'common/js/helpers/email';


const userDefaults = {
        relationship: '',
        title: '',
        first: '',
        middle: '',
        last: '',
        suffix: '',
        keep_name: false,
        print_first_names: '',
        print_other_names: '',
        email: '',
        gender: 'U',
        interest_id: '',
        unlink_address: false,
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
        phone: '',
        can_text: true,
        birth_date: '',
        shirt_size: '',
        polo_size: '',
        athlete_sport_id: null,
        athlete_grad: '',
        athletes_sports_attributes: [],
        checked_background: false,
        set_as_traveling: false,
        departing_date_override: '',
        returning_date_override: '',
        travel_preparation_attributes: {
          early_payoff_deadline: null,
          final_payment_deadline: null,
          rollover_deadline: null,
          two_thousand_deadline: null,
        }
      }

export default class UserForm extends Component {
  constructor(props) {
    super(props)

    const user = Objected.deepClone(userDefaults)

    const { changes } = Objected.existingOnly(user, props.user)

    this.state = {
      showCalendar: false,
      errors: null,
      changed: false,
      isAthlete: !!(props.user || {}).athlete,
      isCoach: !!(props.user || {}).coach,
      allowTravelDates: !!(props.user || {}).allow_travel_dates,
      form: {
        user: {
          ...user,
          ...changes
        },
      }
    }

    this.action = `${this.props.url || '/admin/users'}/${this.props.id || ''}`
  }

  addSport = () => {
    return onFormChange(this, `user.athletes_sports_attributes`, [...(this.state.form.user.athletes_sports_attributes || []), {rank: 7, positions_array: []}], true, ()=>{})
  }

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter
    if(/^user\.(title|first|middle|last|suffix)$/.test(k)) {
      onFormChange(this, 'user.keep_name', false, true, () => {})
    }

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
    this.setState({submitting: true})
    this.handleSubmit()
  }

  handleSubmit = async () => {
    if(!this.state.changed) return this.props.onSuccess()
    try {
      const form = deleteValidationKeys(Objected.deepClone(this.state.form))

      if(!form.user.address_attributes.street || !!form.user.unlink_address) {
        delete form.user.address_attributes
      }

      if(!this.props.user.can_set_starter || !form.set_as_traveling) {
        delete form.set_as_traveling
      }

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

  checkValidDusId = async (e) => {
    e.stopPropagation(e)
    e.preventDefault(e)

    this.setState(state => {
      const form = { ...state.form }
      form.dus_id = dusIdFormat(form.dus_id)
      return { form }
    }, async () => {
      try {
        const dusIdValid = await userIsValid(this.state.form.dus_id)

        this.setState({ dusIdValid })
      } catch(e) {
        let link = baseErrorLink.replace('|PAGE_ERROR|', encodeURIComponent(e.toString() || '')).replace('|USER_AGENT|', encodeURIComponent((window.navigator || {}).userAgent))
        try {
          let linkWithHistory = link.replace(/CONSOLE%3A%20.*/, encodeURIComponent('CONSOLE: ' + JSON.stringify(console.history || [])))
          link = linkWithHistory
        } catch (err) {
        }
        if(link && window.confirm(`The following error occured when attempting to find the requested user: ${e.toString()}. Would you like to report this error?`)) {
          window.location.href = link
        }
      }

    })
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
          className='user-form mb-3'
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
                  form='user'
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
                    ...(
                      this.props.user.can_set_starter ? [
                        {
                          className: 'row',
                          fields: [
                            {
                              className: 'col',
                              fields: [
                                {
                                  field: 'BooleanField',
                                  label: 'Traveler?',
                                  name: `user.set_as_traveling`,
                                  wrapperClass: 'form-group',
                                  checked: !!this.state.form.user.set_as_traveling,
                                  value: !!this.state.form.user.set_as_traveling,
                                  toggle: true,
                                  className: ''
                                },
                              ]
                            }
                          ]
                        }
                      ] : []
                    ),
                    {
                      className: 'row',
                      fields: [
                        ...(
                          (this.props.user.relationship || this.props.showRelationship) ? [
                            {
                              field: 'SelectField',
                              wrapperClass: `col-12 form-group ${this.state.form.user.relationship_validated ? 'was-validated' : ''}`,
                              className:'col',
                              viewProps: {
                                className:'form-control',
                              },
                              label: `Relationship to ${this.props.relationsName || this.documentTitle() || 'Above User'}`,
                              name: 'user.relationship',
                              options: [
                                {
                                  value: 'parent',
                                  label: 'Parent',
                                },
                                {
                                  value: 'guardian',
                                  label: 'Guardian',
                                },
                                {
                                  value: 'grandparent',
                                  label: 'Grandparent',
                                },
                                {
                                  value: 'child',
                                  label: 'Child',
                                },
                                {
                                  value: 'sibling',
                                  label: 'Sibling',
                                },
                                {
                                  value: 'spouse',
                                  label: 'Spouse',
                                },
                                {
                                  value: 'grandchild',
                                  label: 'Grandchild',
                                },
                                {
                                  value: 'auncle',
                                  label: 'Aunt/Uncle',
                                },
                                {
                                  value: 'niephew',
                                  label: 'Niece/Nephew',
                                },
                                {
                                  value: 'cousin',
                                  label: 'Cousin',
                                },
                                {
                                  value: 'ward',
                                  label: 'Ward (inverse of Guardian)',
                                },
                                {
                                  value: 'friend',
                                  label: 'Friend',
                                },
                                {
                                  value: 'coach',
                                  label: 'Coach',
                                },
                                {
                                  value: 'athlete',
                                  label: 'Athlete (inverse of Coach)',
                                },
                              ],
                              value: this.state.form.user.relationship,
                              valueKey: 'value',
                              onChange: true,
                              required: true
                            },
                            ...(this.props.user.dus_id ? [] : [
                              {
                                field: 'TextField',
                                wrapperClass: `col-12 form-group ${this.state.form.dus_id_validated ? 'was-validated' : ''}`,
                                className:'form-control',
                                label: 'DUS ID to Link - ONLY FOR EXISTING USERS',
                                name: 'dus_id',
                                value: this.state.form.dus_id || '',
                                onChange: true,
                                onBlur: this.checkValidDusId
                              },
                              {
                                field: 'h3',
                                className: `col-12 text-center ${this.state.form.dus_id  && (this.state.dusIdValid === 0) ? 'text-danger' : 'text-info' }`,
                                children: this.state.form.dus_id ? ((this.state.dusIdValid === 0) ? 'Invalid DUS ID (click here to check again)' : (this.state.dusIdValid ? '' : '(Click Here)')) : ''
                              },
                              {
                                wrapperClass: 'col-12',
                                field: 'hr'
                              }
                            ])
                          ] : []
                        ),
                        ...(this.state.form.dus_id ? [] : [
                          {
                            field: 'InterestSelectField',
                            wrapperClass: `col-12 form-group ${this.state.form.user.interest_id_validated ? 'was-validated' : ''}`,
                            className:'col',
                            viewProps: {
                              className:'form-control',
                            },
                            label: 'Interest Level',
                            name: 'user.interest_id',
                            value: this.state.form.user.interest_id,
                            valueKey: 'value',
                            onChange: true
                          },
                          {
                            field: 'TextField',
                            wrapperClass: `col-lg-1 form-group ${this.state.form.user.title_validated ? 'was-validated' : ''}`,
                            label: 'Title',
                            name: 'user.title',
                            type: 'text',
                            value: this.state.form.user.title,
                            onChange: true,
                            autoComplete: 'off',
                          },
                          {
                            field: 'TextField',
                            wrapperClass: `col-lg-3 form-group ${this.state.form.user.first_validated ? 'was-validated' : ''}`,
                            label: 'First Name',
                            name: 'user.first',
                            type: 'text',
                            value: this.state.form.user.first,
                            onChange: true,
                            required: true,
                            autoComplete: 'off',
                          },
                          {
                            field: 'TextField',
                            wrapperClass: `col-lg-3 form-group ${this.state.form.user.middle_validated ? 'was-validated' : ''}`,
                            label: 'Middle Name',
                            name: 'user.middle',
                            type: 'text',
                            value: this.state.form.user.middle,
                            onChange: true,
                            autoComplete: 'off',
                          },
                          {
                            field: 'TextField',
                            wrapperClass: `col-lg-4 form-group ${this.state.form.user.last_validated ? 'was-validated' : ''}`,
                            label: 'Last Name',
                            name: 'user.last',
                            type: 'text',
                            value: this.state.form.user.last,
                            onChange: true,
                            required: true,
                            autoComplete: 'off',
                          },
                          {
                            field: 'TextField',
                            wrapperClass: `col-lg-1 form-group ${this.state.form.user.suffix_validated ? 'was-validated' : ''}`,
                            label: 'Suffix',
                            name: 'user.suffix',
                            type: 'text',
                            value: this.state.form.user.suffix,
                            onChange: true,
                            autoComplete: 'off',
                          },
                          ...(this.state.errors ? [
                            {
                              field: 'BooleanField',
                              topLabel: 'Keep Name?',
                              label: !!this.state.form.user.keep_name
                                ? <span className="text-danger">DANGER: FORMATTING, CAPITALIZATION, AND PUNCTUATION WILL BE EXACTLY AS SHOWN ABOVE</span>
                                : <span className="text-success">Name will automagically be cleaned-up</span>,
                              name: 'user.keep_name',
                              wrapperClass: 'col-12 form-group',
                              checked: !!this.state.form.user.keep_name,
                              value: !!this.state.form.user.keep_name,
                              toggle: true,
                              className: ''
                            },
                          ] : []),
                          {
                            field: 'TextField',
                            wrapperClass: `col-lg-6 form-group ${this.state.form.user.suffix_validated ? 'was-validated' : ''}`,
                            label: 'Print First Name(s)',
                            name: 'user.print_first_names',
                            type: 'text',
                            value: this.state.form.user.print_first_names,
                            onChange: true,
                            autoComplete: 'off',
                          },
                          {
                            field: 'TextField',
                            wrapperClass: `col-lg-6 form-group ${this.state.form.user.suffix_validated ? 'was-validated' : ''}`,
                            label: 'Print Other Name(s)',
                            name: 'user.print_other_names',
                            type: 'text',
                            value: this.state.form.user.print_other_names,
                            onChange: true,
                            autoComplete: 'off',
                          },
                        ])
                      ]
                    },
                    ...(
                      this.state.form.dus_id ? [] : [
                        {
                          className: 'row',
                          fields: [
                            {
                              field: 'TextField',
                              wrapperClass: `col-lg-6 form-group ${this.state.form.user.phone_validated ? 'was-validated' : ''}`,
                              label: 'Phone Number',
                              name: `user.phone`,
                              type: 'text',
                              inputMode: 'numeric',
                              value: this.state.form.user.phone,
                              usePhoneFormat: true,
                              onChange: true,
                            },
                            {
                              field: 'BooleanField',
                              topLabel: 'Can Text?',
                              label: 'Can Text?',
                              name: 'user.can_text',
                              wrapperClass: 'col-lg-6 form-group',
                              checked: !!this.state.form.user.can_text,
                              value: !!this.state.form.user.can_text,
                              toggle: true,
                              className: ''
                            },
                            {
                              field: 'TextField',
                              wrapperClass: `col-12 form-group ${this.state.form.user.email_validated ? 'was-validated' : ''}`,
                              label: 'Email',
                              name: `user.email`,
                              type: 'email',
                              value: this.state.form.user.email,
                              onChange: true,
                              useEmailFormat: true,
                              feedback: (
                                <span className={`${emailRegex.test(this.state.form.user.email) ? 'd-none' : 'text-danger'}`}>
                                  Please enter a valid email
                                </span>
                              ),
                            },
                          ]
                        },
                        {
                          className: 'row',
                          fields: [
                            {
                              field: 'InlineRadioField',
                              wrapperClass: `col-12 form-group ${this.state.form.user.gender_validated ? 'was-validated' : ''}`,
                              name: 'user.gender',
                              value: this.state.form.user.gender || '',
                              label: 'Gender',
                              onChange: true,
                              options: [
                                {value: 'M', label: 'Male'},
                                {value: 'F', label: 'Female'},
                                {value: 'U', label: 'Unknown'},
                              ],
                              required: true,
                              className: ''
                            },
                          ]
                        },
                        {
                          className: 'row',
                          fields: [
                            {
                              field: 'ShirtSizeSelectField',
                              wrapperClass: `col-md form-group ${this.state.form.user.shirt_size_validated ? 'was-validated' : ''}`,
                              viewProps: {
                                className:'form-control',
                              },
                              label: 'Shirt Size',
                              name: 'user.shirt_size',
                              value: this.state.form.user.shirt_size,
                              valueKey: 'value',
                              onChange: true,
                            },
                            {
                              field: 'CalendarField',
                              wrapperClass: `col-md form-group ${this.state.form.user.birth_date_validated ? 'was-validated' : ''}`,
                              label: 'Birth Date (YYYY-MM-DD)',
                              name: 'user.birth_date',
                              type: 'text',
                              value: this.state.form.user.birth_date,
                              valueKey: 'value',
                              pattern: "\\d{4}-\\d{2}-\\d{2}",
                              onChange: true,
                              closeOnSelect: true,
                              autoComplete: 'off',
                            },
                            ...(
                              this.state.isAthlete ? [
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-md form-group ${this.state.form.user.athlete_grad_validated ? 'was-validated' : ''}`,
                                  label: 'Year Grad',
                                  name: `user.athlete_grad`,
                                  type: 'text',
                                  inputMode: 'numeric',
                                  value: this.state.form.user.athlete_grad,
                                  pattern: "\\d{4}",
                                  onChange: true,
                                },
                              ] : []
                            ),
                            ...(
                              this.state.isCoach ? [
                                {
                                  field: 'ShirtSizeSelectField',
                                  wrapperClass: `col-md form-group ${this.state.form.user.polo_size_validated ? 'was-validated' : ''}`,
                                  viewProps: {
                                    className:'form-control',
                                  },
                                  label: 'Polo Size',
                                  name: 'user.polo_size',
                                  value: this.state.form.user.polo_size,
                                  valueKey: 'value',
                                  onChange: true,
                                },
                              ] : []
                            )
                          ]
                        },
                        {
                          field: 'hr',
                        },
                        {
                          field: 'AddressSection',
                          className: '',
                          label: 'Address',
                          name: `user.address_attributes`,
                          valuePrefix: `user.address_attributes`,
                          delegatedChange: true,
                          values: this.state.form.user.address_attributes,
                          required: false,
                          inline: true
                        },
                        {
                          field: 'BooleanField',
                          label: 'Unlink Address?',
                          name: `user.unlink_address`,
                          wrapperClass: 'form-group',
                          checked: !!this.state.form.user.unlink_address,
                          value: !!this.state.form.user.unlink_address,
                          toggle: true,
                          className: ''
                        },
                        {
                          field: 'hr',
                        },
                        (this.state.isAthlete ? {
                          field: 'CardSection',
                          label: 'Sports',
                          fields: [
                            (
                              this.props.user.athlete_sport_id ? {
                                className: 'row',
                                fields: [
                                  {
                                    field: 'SportSelectField',
                                    wrapperClass: `col-md form-group ${this.state.form.user.athlete_sport_id ? 'was-validated' : ''}`,
                                    label: 'Selected Sport (must exist in the list below)',
                                    name: `user.athlete_sport_id`,
                                    value: this.state.form.user.athlete_sport_id || '',
                                    onChange: true,
                                    autoCompleteKey: 'label',
                                    valueKey: 'value',
                                    viewProps: {
                                      className: 'form-control',
                                      autoComplete: 'off',
                                      required: false,
                                    },
                                  },
                                ]
                              } : {}
                            ),
                            ...(this.state.form.user.athletes_sports_attributes || []).map((as, s) => ({
                              className: 'row',
                              fields: [
                                (
                                  as.id ? {
                                    field: 'BooleanField',
                                    topLabel: as.sport_abbr,
                                    label: 'Delete?',
                                    name: `user.athletes_sports_attributes.${s}._destroy`,
                                    wrapperClass: 'col-md-3 form-group',
                                    checked: !!as._destroy,
                                    value: !!as._destroy,
                                    toggle: true,
                                    className: ''
                                  } : {
                                    field: 'SportSelectField',
                                    wrapperClass: `col-md form-group ${as.sport_id_validated ? 'was-validated' : ''}`,
                                    label: 'Sport',
                                    name: `user.athletes_sports_attributes.${s}.sport_id`,
                                    value: as.sport_id || '',
                                    onChange: true,
                                    autoCompleteKey: 'label',
                                    valueKey: 'value',
                                    viewProps: {
                                      className: 'form-control',
                                      autoComplete: 'off',
                                      required: false,
                                    },
                                  }
                                ),
                                {
                                  className: 'col-md-4 col-sm-6',
                                  fields: [
                                    {
                                      className: 'row',
                                      fields: [
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-4 col-sm-6 form-group ${as.rank_validated ? 'was-validated' : ''}`,
                                          name: `user.athletes_sports_attributes.${s}.rank`,
                                          label: 'Rank',
                                          value: as.rank || '',
                                          onChange: true,
                                          type: 'number',
                                          min: 1,
                                          max: 7,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-4 col-sm-6 form-group ${as.height_validated ? 'was-validated' : ''}`,
                                          name: `user.athletes_sports_attributes.${s}.height`,
                                          label: 'Height',
                                          value: as.height || '',
                                          onChange: true,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-4 col-sm-6 form-group ${as.weight_validated ? 'was-validated' : ''}`,
                                          name: `user.athletes_sports_attributes.${s}.weight`,
                                          label: 'Weight',
                                          value: as.weight || '',
                                          onChange: true,
                                        },
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-md-6 form-group ${as.handicap_validated ? 'was-validated' : ''}`,
                                          name: `user.athletes_sports_attributes.${s}.handicap`,
                                          label: 'Handicap',
                                          value: as.handicap || '',
                                          onChange: true,
                                        },
                                        {
                                          field: 'ArrayField',
                                          wrapperClass: `col-md-6 form-group ${as.positions_array_validated ? 'was-validated' : ''}`,
                                          className:'col',
                                          viewProps: {
                                            className:'form-control',
                                          },
                                          label: 'Positions',
                                          name: `user.athletes_sports_attributes.${s}.positions_array`,
                                          value: as.positions_array,
                                          valueKey: 'value',
                                          onChange: true
                                        },
                                      ]
                                    }
                                  ]
                                },
                                {
                                  field: 'TextAreaField',
                                  wrapperClass: `col-md form-group ${as.stats_validated ? 'was-validated' : ''}`,
                                  name: `user.athletes_sports_attributes.${s}.stats`,
                                  label: 'Stats',
                                  value: as.stats || '',
                                  onChange: true,
                                },
                                { field: 'hr', wrapperClass: 'col-12' },
                              ]
                            })),
                            {
                              field: 'button',
                              type: 'button',
                              className: 'btn btn-block btn-warning',
                              children: 'Add Sport',
                              onClick: this.addSport
                            }
                          ]
                        } : {}),
                        {
                          field: this.state.isAthlete && 'hr',
                        },
                        {
                          field: 'CardSection',
                          label: 'Deadlines',
                          fields: [
                            {
                              className: 'row',
                              fields: (['early_payoff_deadline', 'final_payment_deadline', 'rollover_deadline', 'two_thousand_deadline', ]).map(k => (
                                {
                                  key: k,
                                  field: 'CalendarField',
                                  wrapperClass: `col-12 form-group ${this.state.form.user.travel_preparation_attributes[`${k}_validated`] ? 'was-validated' : ''}`,
                                  label: `${k.replace(/_/g, ' ').titleize()} (YYYY-MM-DD)`,
                                  name: `user.travel_preparation_attributes.${k}`,
                                  type: 'text',
                                  value: this.state.form.user.travel_preparation_attributes[k],
                                  valueKey: 'value',
                                  pattern: "\\d{4}-\\d{2}-\\d{2}",
                                  onChange: true,
                                  closeOnSelect: true,
                                  autoComplete: 'off',
                                }
                              ))
                            }
                          ]
                        },
                        ...(
                          this.state.allowTravelDates ? [
                            {
                              field: 'hr'
                            },
                            {
                              field: 'CardSection',
                              label: 'Travel Date Overrides',
                              fields: [
                                {
                                  className: 'row',
                                  fields: (['departing_date_override', 'returning_date_override']).map(k => (
                                    {
                                      key: k,
                                      field: 'CalendarField',
                                      wrapperClass: `col-12 form-group ${this.state.form.user[`${k}_validated`] ? 'was-validated' : ''}`,
                                      label: `${k.replace(/_/g, ' ').titleize()} (YYYY-MM-DD)`,
                                      name: `user.${k}`,
                                      type: 'text',
                                      value: this.state.form.user[k],
                                      valueKey: 'value',
                                      pattern: "\\d{4}-\\d{2}-\\d{2}",
                                      onChange: true,
                                      closeOnSelect: true,
                                      autoComplete: 'off',
                                    }
                                  ))
                                }
                              ]
                            }
                          ] : []
                        ),
                        {
                          field: this.state.isCoach && 'hr',
                        },
                        (
                          this.state.isCoach ? {
                            field: 'BooleanField',
                            label: 'Checked Background?',
                            name: `user.checked_background`,
                            wrapperClass: 'form-group',
                            checked: !!this.state.form.user.checked_background,
                            value: !!this.state.form.user.checked_background,
                            toggle: true,
                            className: ''
                          } : {}
                        ),
                      ]
                    ),
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
                      disabled: !!(this.state.form.dus_id && !this.state.dusIdValid),
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
