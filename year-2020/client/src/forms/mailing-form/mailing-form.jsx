import React, {Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import FieldsFromJson from 'common/js/components/fields-from-json';

const addressFields = {
  is_home: false,
  is_foreign: false,
  street: '',
  street_2: '',
  street_3: '',
  city: '',
  state: '',
  zip: '',
  country: '',
}
const mailingFields = {
  category: 'infokit',
  sent: '',
  explicit: false,

}

export default class MailingForm extends Component {
  constructor(props) {
    super(props)

    const mailing = { ...mailingFields, ...addressFields }

    const { changes } = Objected.existingOnly(mailing, props.mailing)

    const merged = {
      ...mailing,
      ...changes
    }

    if(/invite/.test(merged.category)) merged.category = "invite"

    this.state = {
      errors: null,
      changed: false,
      categories: [ "infokit" , "invite" ],
      addressesAvailable: [],
      form: {
        mailing: merged,
      }
    }

    this.action = `/admin/users/${this.props.userId}/mailings/${this.props.id || ''}`
  }

  async componentDidMount() {
    await this.getCategories()
    await this.getAddressesAvailable()
  }

  getAddressesAvailable = async () => {
    try {
      const result = await fetch(`/admin/users/${this.props.userId}/addresses_available.json`),
            json = await result.json()

      console.log(json)
      const fields = { ...addressFields }

      const addressesAvailable = (json.addresses || []).map((value) => ({
        label: value.label,
        value: value.label,
        address: { ...fields, ...(Objected.existingOnly(fields, value.address).changes) } || {}
      }))
      await new Promise(r => this.setState({ addressesAvailable }, r))
    } catch(err) {
      console.error(err)
    }
  }

  getCategories = async () => {
    try {
      const result = await fetch("/admin/mailings/categories.json"),
            json = await result.json()

      console.log(json)
      await new Promise(r => this.setState({categories: json.categories || [ "infokit", "invite_home", "invite_school" ]}, r))
    } catch(err) {
      console.error(err)
    }
  }

  onSelectAddress = (_false, _k, address = {}) =>
    Object.keys(address).map( k => this.onChange(false, `mailing.${k}`, address[k]) )
    && this.setState({ selectedAddress: 'asdf' }, () => setTimeout(() => this.setState({ selectedAddress: '' })))


  onChange = (ev, k, formatter, cb = (() => {})) => {
    console.log("CHANGE", ev, k, formatter, cb)
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
        this.setState({errors: [ err.mailing ], submitting: false})
      }
    }
  }

  onCancel = (e) => {
    e.preventDefault();
    e.stopPropagation();
    return this.props.onCancel && this.props.onCancel();
  }

  deleteMailing = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    if(window.confirm(`Are you sure you want to delete this mailing?`)) {
      this.setState({submitting: true})
      try {

        const result = await fetch(this.action, {
          method: 'PATCH',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify({DELETE_MAILING: true})
        });

        await result.json()

        this.props.onSuccess && this.props.onSuccess()
      } catch(err) {
        try {
          this.setState({errors: (await err.response.json()).errors, submitting: false})
        } catch(e) {
          this.setState({errors: [ err.mailing ], submitting: false})
        }
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
          className='mailing-form mb-3'
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
                  form='mailing'
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
                              onClick: this.onCancel,
                              children: [
                                'Cancel'
                              ]
                            },
                          ]
                        },
                        {
                          className: 'col-auto mb-3',
                          fields: [
                            {
                              field: 'button',
                              className: 'btn btn-warning btn-lg',
                              type: 'submit',
                              onClick: this.props.id ? this.deleteMailing : this.onCancel,
                              children: [
                                'DELETE'
                              ]
                            },
                          ]
                        },
                        {
                          className: 'col mb-3',
                          fields: [
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
                          changeOverride: this.onSelectAddress,
                          valueKey: 'address',
                          viewProps: {
                            className: 'form-control',
                            autoComplete: 'off',
                            required: false,
                          },
                          wrapperClass: `col-12 form-group`,
                          label: 'Select From Existing Address',
                          name: 'addresses_available',
                          options: this.state.addressesAvailable,
                          value: ' '
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
                          label: 'Category',
                          name: 'mailing.category',
                          options: this.state.categories,
                          value: this.state.form.mailing.category
                        },

                        {
                          field: 'CalendarField',
                          wrapperClass: `col-6 form-group ${this.state.form.mailing.sent_validated ? 'was-validated' : ''}`,
                          label: 'Sent Date (YYYY-MM-DD)',
                          name: 'mailing.sent',
                          type: 'text',
                          value: this.state.form.mailing.sent,
                          valueKey: 'value',
                          pattern: "\\d{4}-\\d{2}-\\d{2}",
                          onChange: true,
                          closeOnSelect: true,
                          autoComplete: 'off',
                        },
                        {
                          field: 'BooleanField',
                          skipTopLabel: true,
                          label: 'Is Foreign?',
                          name: `mailing.is_foreign`,
                          wrapperClass: "col-6 form-group",
                          checked: !!this.state.form.mailing.is_foreign,
                          value: !!this.state.form.mailing.is_foreign,
                          toggle: true,
                          className: ''
                        },
                        {
                          field: 'BooleanField',
                          skipTopLabel: true,
                          label: 'Is Home?',
                          name: `mailing.is_home`,
                          wrapperClass: "col-6 form-group",
                          checked: !!this.state.form.mailing.is_home,
                          value: !!this.state.form.mailing.is_home,
                          toggle: true,
                          className: '',
                        },
                        ...(
                          /invite/.test(this.state.form.mailing.category)
                            ? [
                                {
                                  field: 'BooleanField',
                                  skipTopLabel: true,
                                  label: 'Force "Is Home" to Stick? (invites only)',
                                  name: `mailing.explicit`,
                                  wrapperClass: "col-12 form-group",
                                  checked: !!this.state.form.mailing.explicit,
                                  value: !!this.state.form.mailing.explicit,
                                  toggle: true,
                                  className: '',
                                },
                              ]
                            : [
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.mailing.street_validated ? 'was-validated' : ''}`,
                                  className: 'form-control',
                                  label: 'Streets',
                                  name: 'mailing.street',
                                  value: this.state.form.mailing.street || '',
                                  onChange: true,
                                  required: true,
                                  placeholder: 'Line 1'
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.mailing.street_2_validated ? 'was-validated' : ''}`,
                                  className: 'form-control',
                                  skipExtras: true,
                                  name: 'mailing.street_2',
                                  value: this.state.form.mailing.street_2 || '',
                                  onChange: true,
                                  placeholder: 'Line 2'
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.mailing.street_3_validated ? 'was-validated' : ''}`,
                                  className: 'form-control',
                                  skipExtras: true,
                                  name: 'mailing.street_3',
                                  value: this.state.form.mailing.street_3 || '',
                                  onChange: true,
                                  placeholder: 'Line 3'
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-12 form-group ${this.state.form.mailing.city_validated ? 'was-validated' : ''}`,
                                  className: 'form-control',
                                  label: 'City',
                                  name: 'mailing.city',
                                  value: this.state.form.mailing.city || '',
                                  onChange: true,
                                  required: true
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-6 form-group ${this.state.form.mailing.state_validated ? 'was-validated' : ''}`,
                                  className: 'form-control',
                                  label: 'State',
                                  name: 'mailing.state',
                                  value: this.state.form.mailing.state || '',
                                  onChange: true,
                                  required: true
                                },
                                {
                                  field: 'TextField',
                                  wrapperClass: `col-6 form-group ${this.state.form.mailing.zip_validated ? 'was-validated' : ''}`,
                                  className: 'form-control',
                                  label: 'Zip',
                                  name: 'mailing.zip',
                                  value: this.state.form.mailing.zip || '',
                                  onChange: true,
                                  required: true
                                },
                                ...(
                                  this.state.form.mailing.is_foreign
                                    ? [
                                        {
                                          field: 'TextField',
                                          wrapperClass: `col-12 form-group ${this.state.form.mailing.country_validated ? 'was-validated' : ''}`,
                                          className: 'form-control',
                                          label: 'Country',
                                          name: 'mailing.country',
                                          value: this.state.form.mailing.country || '',
                                          onChange: true
                                        },
                                      ]
                                    : []
                                )
                              ]
                        ),
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
              </DisplayOrLoading>
            </div>
          </section>
        </form>
      </DisplayOrLoading>
    )
  }
}
