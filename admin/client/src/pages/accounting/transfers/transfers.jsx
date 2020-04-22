import React          from 'react';
import Component from 'common/js/components/component'
import { SelectField, TextField } from 'react-component-templates/form-components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

const categories = [
        { value: 'refund', label: 'ACH/Other Refund' },
        { value: 'shirts', label: 'T-Shirt Order' },
        { value: 'transaction', label: 'Authorize.net Transaction/Refund' },
        { value: 'transfer', label: 'Transfer Between Users' },
        { value: 'uniform', label: 'Uniform Re-Order' },
      ],
      viewProps = { className: "form-control" }

export default class Transfers extends Component {
  state = {
    amount: '',
    autoComplete: `false ${(new Date())}`,
    category: '',
    errors: null,
    fromId: '',
    quantity: '',
    submitting: false,
    success: false,
    toId: '',
    transactionId: '',
  }

  _handleError = async (err) => {
    try {
      const errorResponse = await err.response.json()
      console.log(errorResponse)
      return await this.setStateAsync({errors: errorResponse.errors || [ errorResponse.message || err.toString() ], submitting: false, success: false})
    } catch(e) {
      return await this.setStateAsync({errors: [ err.message || err.toString() ], submitting: false, success: false})
    }
  }

  _handleSuccess = () => {
    this.setState({
      amount: '',
      autoComplete: `false ${(new Date())}`,
      category: '',
      errors: null,
      fromId: '',
      quantity: '',
      success: true,
      submitting: false,
      toId: '',
      transactionId: '',
    }, () => {
      setTimeout(() => {
        this.setState({ success: false })
      }, 2000)
    })
  }

  _handleSubmit = async () => {
    try {
      await this.setStateAsync({ submitting: true, errors: null })

      const transfer = {}
      switch (this.state.category) {
        case 'refund':
          if(!(transfer.amount   = this.state.amount))    throw new Error('Invalid Amount')
          if(!(transfer.from     = this.state.fromId))   throw new Error('Invalid User')

          transfer.is_refund = true
          break;
        case 'transaction':
          if(!(transfer.transaction_id = this.state.transactionId)) throw new Error('Invalid Transaction')
          if(!(transfer.user          = this.state.fromId))        throw new Error('Invalid User')

          transfer.is_transaction_lookup = true
          break;
        case 'transfer':
          if(!(transfer.amount = this.state.amount)) throw new Error('Invalid Amount')
          if(!(transfer.from   = this.state.fromId)) throw new Error('Invalid User to Transfer From')
          if(!(transfer.to     = this.state.toId))   throw new Error('Invalid User to Transfer To')
          break;
        case 'uniform':
          if(!(transfer.amount   = this.state.amount))    throw new Error('Invalid Amount')
          if(!(transfer.from     = this.state.fromId))    throw new Error('Invalid User to Transfer From')

          transfer.is_uniform = true
          break;
        default:
          if(!(transfer.amount   = this.state.amount))    throw new Error('Invalid Amount')
          if(!(transfer.from     = this.state.fromId))   throw new Error('Invalid User to Transfer From')
          if(!(transfer.quantity = +this.state.quantity)) throw new Error('Invalid # of Shirts Paid For')
      }

      const response = await fetch('/admin/accounting/transfers', {
        method: 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ transfer })
      })

      console.log(await response.json())

      this._handleSuccess()
    } catch(err) {
      await this._handleError(err)
    }
  }

  _onChange              = (key, ev) => this.setState({ [key]: ev.currentTarget.value || '' })
  _onAmountChange        = (ev) => this._onChange('amount', ev)
  _onCategoryChange      = (_, { value: category = '' }) => this.setState({ category })
  _onFromIdChange        = (ev) => this._onChange('fromId', ev)
  _onQuantityChange      = (ev) => this._onChange('quantity', ev)
  _onToIdChange          = (ev) => this._onChange('toId', ev)
  _onTransactionIdChange = (ev) => this._onChange('transactionId', ev)


  _onSubmitButtonClick = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this._handleSubmit()
  }

  componentDidMount() {
    this.setState({autoComplete: `false ${(new Date())}`})
  }

  renderCategory() {
    return (
      <div className="row was-validated">
        <div className="col form-group">
          <SelectField
            viewProps={viewProps}
            label="Category"
            onChange={this._onCategoryChange}
            autoComplete={this.state.autoComplete}
            feedback="Type Of Transfer"
            value={this.state.category}
            options={categories}
            required
          />
        </div>
      </div>
    )
  }

  renderErrors() {
    return (
      <div className="row was-validated">
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

  renderForm() {
    switch(this.state.category) {
      case 'refund':
        return (
          <div key='refund' className="row was-validated">
            <div className="col form-group">
              <TextField
                className="form-control"
                label="Transfer Amount"
                type="text"
                useCurrencyFormat
                onChange={this._onAmountChange}
                autoComplete={this.state.autoComplete}
                placeholder="(300.00)"
                feedback="Amount to refund"
                value={this.state.amount}
                required
              />
            </div>
            <div className="col form-group">
              <TextField
                className="form-control"
                label="User DUS ID"
                type="text"
                onChange={this._onFromIdChange}
                autoComplete={this.state.autoComplete}
                placeholder="(AAA-AAA)"
                feedback="DUS ID of User to Transfer From"
                value={this.state.fromId}
                required
              />
            </div>
          </div>
        )
      case 'transaction':
        return (
          <div key="transaction" className="row was-validated">
            <div className="col form-group">
              <TextField
                className="form-control"
                label="Transaction ID"
                type="text"
                onChange={this._onTransactionIdChange}
                autoComplete={this.state.autoComplete}
                placeholder="(123456789)"
                feedback="Authorize.net Transaction ID"
                value={this.state.transactionId}
                required
              />
            </div>
            <div className="col form-group">
              <TextField
                className="form-control"
                label="User DUS ID"
                type="text"
                onChange={this._onFromIdChange}
                autoComplete={this.state.autoComplete}
                placeholder="(AAA-AAA)"
                feedback="DUS ID of User"
                value={this.state.fromId}
                required
              />
            </div>
          </div>
        )
      case 'transfer':
        return (
          <div key="transfer" className="row was-validated">
            <div className="col form-group">
              <TextField
                className="form-control"
                label="Transfer Amount"
                type="text"
                useCurrencyFormat
                onChange={this._onAmountChange}
                autoComplete={this.state.autoComplete}
                placeholder="(300.00)"
                feedback="Amount to Transfer"
                value={this.state.amount}
                required
              />
            </div>
            <div className="col form-group">
              <TextField
                className="form-control"
                label="From DUS ID"
                type="text"
                onChange={this._onFromIdChange}
                autoComplete={this.state.autoComplete}
                placeholder="(AAA-AAA)"
                feedback="DUS ID of User to Transfer From"
                value={this.state.fromId}
                required
              />
            </div>
            <div className="col form-group">
              <TextField
                className="form-control"
                label="To DUS ID"
                type="text"
                onChange={this._onToIdChange}
                autoComplete={this.state.autoComplete}
                placeholder="(AAA-AAA)"
                feedback="DUS ID of User to Transfer To"
                value={this.state.toId}
                required
              />
            </div>
          </div>
        )
      case 'uniform':
        return (
          <div key="uniform" className="row was-validated">
            <div className="col form-group">
              <TextField
                className="form-control"
                label="Charge Amount"
                type="text"
                useCurrencyFormat
                onChange={this._onAmountChange}
                autoComplete={this.state.autoComplete}
                placeholder="(300.00)"
                feedback="Amount to Charge for Uniform"
                value={this.state.amount}
                required
              />
            </div>
            <div className="col form-group">
              <TextField
                className="form-control"
                label="From DUS ID"
                type="text"
                onChange={this._onFromIdChange}
                autoComplete={this.state.autoComplete}
                placeholder="(AAA-AAA)"
                feedback="DUS ID of User"
                value={this.state.fromId}
                required
              />
            </div>
          </div>
        )
      default:
        return (
          <div className="row was-validated">
            <div className="col form-group">
              <TextField
                className="form-control"
                label="Charge Amount"
                type="text"
                useCurrencyFormat
                onChange={this._onAmountChange}
                autoComplete={this.state.autoComplete}
                placeholder="(300.00)"
                feedback="Amount to Charge for Shirts/Uniform"
                value={this.state.amount}
                required
              />
            </div>
            <div className="col form-group">
              <TextField
                className="form-control"
                label="Quantity"
                inputMode="numeric"
                onChange={this._onQuantityChange}
                autoComplete={this.state.autoComplete}
                placeholder="(1)"
                pattern="[1-9][0-9]*"
                feedback="Number of PAID shirts ordered"
                value={this.state.quantity}
                required
              />
            </div>
            <div className="col form-group">
              <TextField
                className="form-control"
                label="From DUS ID"
                type="text"
                onChange={this._onFromIdChange}
                autoComplete={this.state.autoComplete}
                placeholder="(AAA-AAA)"
                feedback="DUS ID of User"
                value={this.state.fromId}
                required
              />
            </div>
          </div>
        )
    }
  }

  renderSubmit() {
    return (
      <div className="row was-validated">
        <div className="col">
          <button
            className="btn btn-block btn-primary"
            onClick={this._onSubmitButtonClick}
          >
            Submit
          </button>
        </div>
      </div>
    )
  }

  renderSuccess() {
    return (
      <div className="row was-validated">
        <div className="col">
          {
            this.state.success && <div className="alert alert-success form-group">
              Submitted!
            </div>
          }
        </div>
      </div>
    )
  }

  render() {
    return (
      this.state.submitting ? (
        <JellyBox className="page-loader"/>
      ) : (
        <>
          { this.renderSuccess() }
          { this.renderErrors() }
          { this.renderCategory() }
          { this.renderForm() }
          { this.renderSubmit() }
        </>
      )
    )
  }
}
