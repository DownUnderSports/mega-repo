import React from 'react'
import Component from 'common/js/components/component'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import FieldsFromJson from 'common/js/components/fields-from-json';
//import authFetch from 'common/js/helpers/auth-fetch'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

export default class CreditForm extends Component {
  get categoryTable() {
    return this._categoryTable || (
      (this.props.categories || []).length && (
        this._categoryTable = (
          <table  key="categories-table" className="table table-striped table-bordered mt-2">
            <thead>
              <tr>
                <th>name</th>
                <th>count</th>
                <th>smallest</th>
                <th>largest</th>
              </tr>
            </thead>
            <tbody>
              {
                this.props.categories.map((cat) => (
                  <tr className="clickable" key={cat.name} data-name={cat.name} data-amount={cat.smallest} data-description={cat.description} onClick={this.setValues}>
                    <td>{cat.name}</td>
                    <td>{cat.count}</td>
                    <td>{cat.smallest}</td>
                    <td>{cat.largest}</td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        )
      )
    ) || 'Enter a Name'
  }

  constructor(props) {
    super(props)

    const credit = {
      id: props.id,
      dus_id: props.dus_id,
      user: props.user,
      name: props.name || '',
      description: props.description || '',
      amount: props.amount.decimal && currencyFormat(props.amount.decimal)
    }

    const state = {
      errors: null,
      changed: false,
      ogCredit: { ...credit },
      form: { credit },
      addDate: props.add_date
    }

    this.state = state
  }

  setValues = (ev) => {
    const { name, amount, description } = ev.currentTarget.dataset || {}
    name && this.setState(state => {
      const form = { ...(state.form || {}) }
      form.credit = { ...(form.credit || {}) }
      form.credit.name = name || ''
      form.credit.amount = amount ? `${amount.replace(/,/g, '').replace(/\$/, '')}.00`.replace(/(\.\d+)\.\d+/, "$1") : '0.00'
      form.credit.description = description || ''
      return { form }
    }, this.hideCategories)
  }

  hideCategories = () => this.setState({ showCategories: false })
  toggleCategories = () => this.setState({ showCategories: !this.state.showCategories })

  onChange = (ev, k, formatter, cb = (() => {})) => {
    const v = ev ? (formatter ? this[formatter](ev.currentTarget.value) : ev.currentTarget.value) : formatter

    if(/dus_id/.test(String(k))) {
      clearTimeout(this._checkValid)
      this._checkValid = setTimeout(this.checkCanRequest, 1500)
    }

    return onFormChange(this, k, v, !(/\.?amount$/.test(k) && this.invalidAmount(v)), cb)
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

  invalidAmount = (amount) => (!!(parseFloat(amount || 0, 10) < parseFloat(0, 10)))

  handleSubmit = async () => {
    try {
      if(this.invalidAmount(this.state.form.credit.amount)) {
        throw new Error('Minimum Payment Amount not met')
      }
      const form = deleteValidationKeys(Objected.deepClone(this.state.form))

      await this.sendRequest(form)
    } catch(err) {
      await this.handleError(err)
    }
  }

  deleteCredit = async (ev) => {
    ev && ev.preventDefault()
    try {
      if(!this.props.id) return this.props.history.push(this.props.indexUrl)
      if(window.confirm("Are you sure? This cannot be undone.")) await this.sendRequest({}, true)
    } catch(err) {
      await this.handleError(err)
    }
  }

  sendRequest = async (form, deleting = false) => {
    await this.setStateAsync({ submitting: true })

    await fetch(this.props.url, {
      method: deleting ? 'DELETE' : (this.props.id ? 'PATCH' : 'POST'),
      headers: {
        "Content-Type": "application/json; charset=utf-8"
      },
      body: JSON.stringify(form)
    })

    return (await this.props.getCredits()) && this.props.history.push(this.props.indexUrl)
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
            </div>
          }
        </div>
      </div>
    )
  }

  render(){
    const { url } = this.props

    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        <form
          action={url}
          method='post'
          className='credit-form mb-3'
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
                  fields={[
                    {
                      className: 'row',
                      fields: this.state.addDate ? [
                        {
                          field: 'h4',
                          wrapperClass: 'col text-center',
                          children: `Add Date: ${this.state.addDate}`
                        }
                      ] : []
                    },
                    {
                      className: 'row',
                      fields: [
                        {
                          field: 'TextField',
                          wrapperClass: `col-md-6 form-group ${this.state.form.credit.amount_validated ? 'was-validated' : ''}`,
                          label: 'Credit Amount',
                          name: 'credit.amount',
                          type: 'text',
                          inputMode: 'numeric',
                          value: this.state.form.credit.amount || '',
                          useCurrencyFormat: true,
                          onChange: true,
                          placeholder: '200.0',
                          autoComplete: 'off',
                          required: true
                        },
                        {
                          field: 'TextField',
                          wrapperClass: `col-md-6 form-group ${this.state.form.credit.name_validated ? 'was-validated' : ''}`,
                          label: 'Credit Name',
                          name: 'credit.name',
                          type: 'text',
                          value: this.state.form.credit.name || '',
                          onChange: true,
                          autoComplete: 'off',
                          placeholder: 'Instant Discount',
                          feedback: this.categoryTable,
                          required: true
                        },
                        {
                          field: 'TextAreaField',
                          wrapperClass: `col-12 form-group ${this.state.form.credit.description_validated ? 'was-validated' : ''}`,
                          label: 'Credit Description',
                          name: 'credit.description',
                          type: 'text',
                          value: this.state.form.credit.description || '',
                          onChange: true,
                          autoComplete: 'off',
                          feedback: 'Enter a description',
                          required: false
                        },
                        {
                          field: 'CalendarField',
                          wrapperClass: `col-lg-6 col-md-8 form-group ${this.state.form.credit.created_at_override_validated ? 'was-validated' : ''}`,
                          label: 'Override Applied Date (YYYY-MM-DD)',
                          name: 'credit.created_at_override',
                          type: 'text',
                          value: this.state.form.credit.created_at_override || '',
                          valueKey: 'value',
                          pattern: '[0-9]{4}-[0-9]{2}-[0-9]{2}',
                          onChange: true,
                          autoComplete: 'off',
                          required: false,
                        },
                      ]
                    },
                    {
                      field: 'hr'
                    },
                    {
                      className: 'row',
                      fields: [
                        (
                          this.state.showCategories
                            ? {
                                className: 'col-12',
                                children: [
                                  <button key="toggle-categories-button" type="button" className="btn btn-secondary" onClick={this.toggleCategories}>
                                    Hide Categories
                                  </button>,
                                  this.categoryTable
                                ]
                              }
                            : {}
                        ),
                        {
                          field: 'button',
                          wrapperClass: 'col form-group',
                          className: 'btn btn-secondary',
                          type: 'button',
                          onClick: this.toggleCategories,
                          children: this.state.showCategories ? 'Hide Categories' : 'Show Categories'
                        },
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
                          onClick: this.deleteCredit,
                          children: 'Delete Credit'
                        },
                        {
                          field: 'button',
                          wrapperClass: 'col form-group',
                          className: 'btn btn-primary btn-lg active float-right',
                          type: 'submit',
                          children: 'Submit Credit'
                        }
                      ]
                    },
                  ]}
                />
                {this.renderErrors()}
              </DisplayOrLoading>
            </div>
          </section>
        </form>
      </DisplayOrLoading>
    )
  }
}
