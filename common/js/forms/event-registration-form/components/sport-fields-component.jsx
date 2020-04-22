import React, { Component } from 'react'
import { DisplayOrLoading } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import ArrayField from 'common/js/forms/components/array-field'

export default class SportFieldsComponent extends Component {
  state = { completed: false, submitting: false }
  category = {
    height: {unit: ' (Inches)', placeholder: '(72)'},
    weight: {unit: ' (Pounds)', placeholder: '(150)'},
    handicap: {unit: '', placeholder: '(72)'},
  }

  get parentForm() {
    return this.props.parent || {state: {}, props: {}}
  }

  get parentState() {
    return this.parentForm.state || {}
  }

  get parentProps() {
    return this.parentForm.props || {}
  }

  componentDidMount() {
    this.parentForm.onChange('sport_id', this.parentForm.sportMappings[this.sportAbbr()])
  }

  sportAbbr = () => null
  positions = () => false
  positionTypes = () => false
  height = () => false
  weight = () => false
  handicap = () => false

  onChange = (ev, value) => this.parentForm.onChange(ev.currentTarget.name, (ev.currentTarget.value || '').replace(/[^0-9]/g, ''))

  onPositionsChange = (_, {value}) => this.parentForm.onChange('positions_array', value)

  onSubmit = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.parentForm.setState({submitting: true}, this.handleSubmit)
  }

  handleSubmit = async () => {
    try {
      const values = { ...this.parentState }

      const result =  await fetch(`/api/departure_checklists/${this.parentProps.id}/registration`, {
        method: 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({registration: values })
      });

      await result.json()
      this.parentForm.setState({ completed: true, submitting: false }, () => {
        this.parentProps.onSuccess && setTimeout(this.parentProps.onSuccess, 2000)
      })
    } catch(err) {
      try {
        this.parentForm.setState({errors: (await err.response.json()).errors, submitting: false})
      } catch(e) {
        this.parentForm.setState({errors: [ err.toString() ], submitting: false})
      }
    }
  }

  render() {
    return this.parentState.completed ? (
      <section className="list-group-item">
        <header>
          <h3 className="mt-3 alert alert-success" role="alert">
            Event Registration Successfully Submitted!
          </h3>
        </header>
        {
          this.parentProps.onSuccess && (
            <p>
              You will be redirected to the checklist page shortly...
            </p>
          )
        }
      </section>
    ) : (
      <DisplayOrLoading
        display={!this.parentState.submitting}
        loadingElement={
          <JellyBox className="page-loader" />
        }
      >
        <form
          action={`/api/departure_checklists/${this.parentProps.id}/registration`}
          onSubmit={this.onSubmit}
          className="was-validated"
        >
          <div className="list-group-item">
            <TextField
              label={<span>Years Played<span className="text-danger">*</span> (Club & High School)</span>}
              name="years_played"
              value={this.parentState.years_played || ''}
              className='form-control'
              pattern="^[0-9]+$"
              placeholder="1"
              onChange={this.onChange}
              inputMode="numeric"
              required
            />
          </div>
          {
            this.positions() && (
              <div className="list-group-item">
                <ArrayField
                  label={<span>Positions<span className="text-danger">*</span> (Abbr; e.g. {this.positionTypes()})</span>}
                  name='positions'
                  value={this.parentState.positions_array || []}
                  viewProps={{
                    className:'form-control',
                    // pattern: "^[A-Z]{1,3}(,\s+[A-Z]{1,3})*$"
                  }}
                  onChange={this.onPositionsChange}
                  pattern="^[A-Z]{1,3}$"
                  maxLength="3"
                  placeholder={this.positions()}
                  required
                />
              </div>
            )
          }
          {
            [
              'height',
              'weight',
              'handicap'
            ].map((k, i) => (
              this[k]() && (
                <div key={k} className="list-group-item">
                  <TextField
                    label={<span>{k.capitalize()}{(k === 'handicap') && <span className="text-danger">*</span>}{this.category[k].unit}</span>}
                    name={k}
                    value={this.parentState[k] || ''}
                    className='form-control'
                    pattern="^[0-9]+$"
                    placeholder={this.category[k].placeholder}
                    onChange={this.onChange}
                    inputMode="numeric"
                    required={k === 'handicap'}
                  />
                </div>
              )
            ))
          }
          {
            this.handicap() && (
              <div className="list-group-item">
                <label htmlFor="handicap_category" className="form-label">
                  Number of Holes<span className="text-danger">*</span>
                </label>
                <select
                  className="form-control"
                  name="handicap_category"
                  id="handicap_category"
                  onChange={this.onChange}
                  value={this.parentState.handicap_category || ''}
                  required
                >
                  <option value="" disabled></option>
                  <option value="9">9</option>
                  <option value="18">18</option>
                </select>
              </div>
            )
          }
          <div className="list-group-item">
            <div className="row">
              <div className="col">
                <span className="text-danger">*</span> Indicates a required field
              </div>
              <div className="col-auto">
                <button
                  className="btn btn-primary"
                  type="submit"
                >
                  Submit Registration
                </button>
              </div>
            </div>
          </div>
          {
            this.parentState.errors && (
              <div className="list-group-item wide-label">
                {
                  this.parentState.errors.map((err, i) => (
                    <div key={i} className="mt-3 alert alert-danger" role="alert">
                      { err }
                    </div>
                  ))
                }
              </div>
            )
          }
        </form>
      </DisplayOrLoading>
    )
  }
}
