import React from 'react'
import Component from 'common/js/components/component'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import FieldsFromJson from 'common/js/components/fields-from-json';
//import authFetch from 'common/js/helpers/auth-fetch'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
// import { emailRegex } from 'common/js/helpers/email';

export default class NewChatForm extends Component {
  constructor(props) {
    super(props)

    const chat_room = {
      name: props.name || '',
      email: props.description || '',
      phone: props.phone || ''
    }

    const state = {
      errors: null,
      changed: false,
      form: { chat_room },
    }

    this.state = state
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

  onSubmit = (e) => {
    e && e.preventDefault();
    this.setState({submitting: true}, () => this.handleSubmit())
  }

  onCancel = (e) => {
    e && e.preventDefault();
    this.props.onCancel && this.props.onCancel()
  }

  invalidAmount = (amount) => (!!(parseFloat(amount || 0, 10) < parseFloat(0, 10)))

  handleSubmit = async () => {
    try {
      if(this.props.uuid) return await this.reopen()
      // if(!this.state.form.chat_room.email) throw new Error('Email is Required')
      if(!this.state.form.chat_room.name) throw new Error('Name is Required')

      const form = deleteValidationKeys(Objected.deepClone(this.state.form))

      await this.sendRequest(form)
    } catch(err) {
      await this.handleError(err)
    }
  }

  reopen = async () => {
    return await this.sendRequest({ uuid: this.props.uuid, reopen: true })
  }

  sendRequest = async (form, deleting = false) => {
    await this.setStateAsync({ submitting: true })

    const result = await fetch('/api/chat_rooms', {
                    method: 'POST',
                    headers: {
                      "Content-Type": "application/json; charset=utf-8"
                    },
                    body: JSON.stringify(form)
                  }),
          json = await result.json()

    return this.props.onSuccess ? this.props.onSuccess(json) : this.setState({submitting: false})
  }

  handleError = async (err) => {
    try {
      const errorResponse = await err.response.json()
      console.log(errorResponse)
      return await this.setStateAsync({errors: errorResponse.errors || [ errorResponse.message ], submitting: false})
    } catch(e) {
      return await this.setStateAsync({errors: [ err.message ], submitting: false})
    }
  }

  renderErrors() {
    return (
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
              <div className="row mt-3">
                <div className="col">
                  You can also <a href="mailto:mail@downundersports.com">send us an email at mail@downundersports.com</a>, or <a href="tel:+14357534732">call or text us at (435) 753-4732</a> at any time.
                </div>
              </div>
            </div>
          }
        </div>
      </div>
    )
  }

  get newChatFields() {
    return [
      {
        className: 'row',
        fields: [
          {
            field: 'TextField',
            wrapperClass: `col-12 form-group ${this.state.form.chat_room.name_validated ? 'was-validated' : ''}`,
            label: 'Your Name',
            name: 'chat_room.name',
            type: 'text',
            value: this.state.form.chat_room.name || '',
            onChange: true,
            autoComplete: 'off',
            placeholder: '(John Smith)',
            required: true
          },
          // {
          //   field: 'TextField',
          //   wrapperClass: `col-lg-6 form-group ${this.state.form.chat_room.email_validated ? 'was-validated' : ''}`,
          //   className: 'form-control form-group',
          //   label: 'Email',
          //   placeholder: '(your@email.com)',
          //   name: 'chat_room.email',
          //   type: 'email',
          //   value: this.state.form.chat_room.email || '',
          //   onChange: true,
          //   useEmailFormat: true,
          //   feedback: !!this.state.form.chat_room.email && (
          //     <span className={`${emailRegex.test(this.state.form.chat_room.email) ? 'd-none' : 'text-danger'}`}>
          //       Please enter a valid email
          //     </span>
          //   )
          // },
          // {
          //   field: 'TextField',
          //   wrapperClass: `col-lg-6 form-group ${this.state.form.chat_room.phone_validated ? 'was-validated' : ''}`,
          //   label: 'Phone Number',
          //   name: 'chat_room.phone',
          //   placeholder: '(435-753-4732)',
          //   type: 'text',
          //   inputMode: 'numeric',
          //   value: this.state.form.chat_room.phone || '',
          //   usePhoneFormat: true,
          //   onChange: true,
          // },
        ]
      },
      {
        field: 'hr'
      },
      {
        className: 'row',
        fields: [
          {
            field: 'button',
            wrapperClass: 'col form-group',
            className: 'btn btn-danger btn-lg active float-left',
            type: 'button',
            children: 'Cancel',
            onClick: this.onCancel
          },
          {
            field: 'button',
            wrapperClass: 'col form-group',
            className: 'btn btn-primary btn-lg active float-right',
            type: 'submit',
            children: 'Start Chat'
          }
        ]
      },
    ]
  }

  get recreateFields() {
    return [
      {
        className: 'row',
        fields: [
          {
            field: 'h4',
            wrapperClass: 'col text-center',
            children: <span>
              This chat has been closed. <br/>
              Click "Reopen Chat" continue or "Restart" to start a new session.
            </span>
          }
        ]
      },
      {
        field: 'hr'
      },
      {
        field: 'button',
        wrapperClass: 'col form-group',
        className: 'btn btn-danger btn-lg active float-left',
        type: 'button',
        children: 'Restart',
        onClick: this.onCancel
      },
      {
        className: 'row',
        fields: [
          {
            field: 'button',
            wrapperClass: 'col form-group',
            className: 'btn btn-primary btn-lg active float-right',
            type: 'submit',
            children: 'Reopen Chat'
          }
        ]
      },
    ]
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
          action="/api/chat_rooms"
          method='post'
          className='new-chat-form mb-3'
          onSubmit={this.onSubmit}
          autoComplete="off"
        >
          <input autoComplete="false" type="text" name="autocomplete" style={{display: 'none'}}/>
          {this.renderErrors()}
          <section>
            <div className='main m-0'>
              <DisplayOrLoading display={!this.state.checkingId}>
                <FieldsFromJson
                  onChange={this.onChange}
                  form='payment'
                  fields={this.props.uuid ? this.recreateFields : this.newChatFields}
                />
              </DisplayOrLoading>
            </div>
          </section>
        </form>
      </DisplayOrLoading>
    )
  }
}
