import React                from 'react'
import AsyncComponent       from 'common/js/components/component/async'
import { Objected }         from 'react-component-templates/helpers';
import { InlineRadioField } from 'react-component-templates/form-components';
import JellyBox             from  'load-awesome-react-components/dist/square/jelly-box'
import onFormChange         from 'common/js/helpers/on-form-change';

const defaults = {
        loading: false,
        form: {
          difficulty: '',
          status: '',
          can_transfer: 'U',
          can_compete: 'U',
          notes: '',
        },
        errors: null,
        success: null,
      },
      difficulties = [
        'extreme',
        'hard',
        'moderate',
        'easy',
        'none'
      ],
      statuses = [
        'evaluated',
        'contacted',
        'confirmed',
        'completed'
      ],
      yesNoUnknown = [
        {value: 'Y', label: 'Yes'},
        {value: 'N', label: 'No'},
        {value: 'U', label: 'Unknown'},
      ]

export default class TransferExpectationsForm extends AsyncComponent {
  state = Objected.deepClone(defaults)

  valueKey = () => 'transfer_expectation'
  resultKey = () => 'form'
  mainKey = () => this.props.id
  url = (id = this.props.id) => `/admin/users/${id}/transfer_expectation`

  onChange = (ev) => {
    return onFormChange(this, ev.currentTarget.dataset.key, ev.currentTarget.value, true)
  }

  onTransferChange = (value) =>
    onFormChange(this, 'can_transfer', value, true)

  onCompeteChange = (value) =>
    onFormChange(this, 'can_compete', value, true)

  componentDidUpdate() {
    clearTimeout(this._confirmedTimeout)
    if(this.isConfirmed) {
      this._confirmedTimeout = setTimeout(() => window.location.reload(), 5000)
    }
  }

  componentWillUnmount() {
    clearTimeout(this._confirmedTimeout)
    return AsyncComponent.prototype.componentWillUnmount.call(this)
  }


  reset = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.afterMount()
  }

  validate = form => {
    if(!form.status) throw new Error("Current Status is Required")
    if(!form.difficulty) throw new Error("Expected Difficulty is Required")
  }

  submit = (ev) => {
    try {
      ev.preventDefault()
      ev.stopPropagation()
    } catch(_) {}

    this.setState({ loading: true, success: null, errors: null }, async () => {
      try {
        const { changed = false, changes: state } = Objected.existingOnly(defaults, this.state)

        if(!changed) throw new Error("Nothing to Submit")

        this.validate(state.form || {})

        const options = {
          method: 'PATCH',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify({ transfer_expectation: state.form })
        }

        const result = await fetch(this.url(), options)

        await result.json()

        this.setState({
          errors: null,
          success: true,
        }, this.afterMount)
      } catch(err) {
        console.log(err)
        try {
          this.setState({errors: (await err.response.json()).errors, loading: false})
        } catch(e) {
          console.log(e)
          this.setState({errors: [ err.message ], loading: false})
        }
      }
    })
  }
    // this.onChange(false, 'status', value)

  mapOptions(options) {
    return [
      <option key="unselected" value="" disabled> -- SELECT -- </option>,
      ...(
        options
          .map((option) => <option key={option} value={option}>{option}</option>)
      )
    ]
  }

  get hasErrors() {
    return !!this.state.errors
      && !!this.state.errors.length
  }

  get isSuccessful() {
    return !!this.state.success
  }

  get isConfirmed() {
    try {
      return this.isSuccessful && (this.state.form.status === 'confirmed')
    } catch(err) {
      return false
    }
  }

  renderErrors = () => (
    <div className="alert alert-danger mb-3" role="alert">
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
  )

  renderSuccess = () => this.isSuccessful && (
    <div className="alert alert-success mb-3" role="alert">
      Info Saved! {this.isConfirmed && 'This page will refresh in 5 seconds'}
    </div>
  )

  render() {
    return this.state.loading
      ? (
        <JellyBox className="page-loader" />
      )
      : (
        <form
          action={this.url()}
          className="p-0"
          method="PATCH"
          autoComplete="off"
          onSubmit={this.submit}
        >
          {
            this.hasErrors
              ? this.renderErrors()
              : this.renderSuccess()
          }
          <div className="row">
            <div className="col-md-6 form-group">
              <label htmlFor="transfer-status">
                <strong>
                  Current Status
                </strong>
              </label>
              <select
                name="transfer_expectation[status]"
                id="transfer-status"
                className="form-control"
                value={this.state.form.status}
                onChange={this.onChange}
                data-key="status"
              >
                {
                  this.mapOptions(statuses)
                }
              </select>
            </div>
            <div className="col-md-6 form-group">
              <label htmlFor="transfer-difficulty">
                <strong>
                  Expected Difficulty
                </strong>
              </label>
              <select
                name="transfer_expectation[difficulty]"
                id="transfer-difficulty"
                className="form-control"
                value={this.state.form.difficulty}
                onChange={this.onChange}
                data-key="difficulty"
              >
                {
                  this.mapOptions(difficulties)
                }
              </select>
            </div>
            <div className="col-12 form-group">
              <InlineRadioField
                id="transfer-can_transfer"
                label={
                  <strong>
                    Can Transfer?
                  </strong>
                }
                name="transfer_expectation[can_transfer]"
                value={this.state.form.can_transfer}
                options={yesNoUnknown}
                onChange={this.onTransferChange}
                data-key="can_transfer"
              />
            </div>
            <div className="col-12 form-group">
              <InlineRadioField
                id="transfer-can_compete"
                label={
                  <strong>
                    Can Compete?
                  </strong>
                }
                name="transfer_expectation[can_compete]"
                value={this.state.form.can_compete}
                options={yesNoUnknown}
                onChange={this.onCompeteChange}
                data-key="can_compete"
              />
            </div>
            <div className="col-12 form-group">
              <label htmlFor="transfer-notes">
                <strong>
                  Other Notes
                </strong>
              </label>
              <textarea
                name="transfer_expectation[notes]"
                id="transfer-notes"
                className="form-control"
                rows="5"
                value={this.state.form.notes}
                onChange={this.onChange}
                data-key="notes"
              />
            </div>
            <div className="col-6">
              <button
                type="button"
                className="btn btn-block btn-danger"
                onClick={this.reset}
              >
                Reset
              </button>
            </div>
            <div className="col-6">
              <button
                type="submit"
                className="btn btn-block btn-primary"
              >
                Submit
              </button>
            </div>
          </div>
        </form>
      )
  }
}
