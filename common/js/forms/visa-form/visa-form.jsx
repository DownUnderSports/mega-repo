import React from 'react'
import Component from 'common/js/components/component'
import { Objected } from 'react-component-templates/helpers'
import { DisplayOrLoading } from 'react-component-templates/components';
import { InlineRadioField } from 'react-component-templates/form-components';
import ArrayField from 'common/js/forms/components/array-field';
import CalendarField from 'common/js/forms/components/calendar-field'
import ShirtSizeSelectField from 'common/js/forms/components/shirt-size-select-field'
import dateFns from 'date-fns'
import './visa-form.css'

export const visaBaseState = {
  has_convictions: 'U',
  convictions_array: [],
  has_multiple_citizenships: 'U',
  citizenships_array: [],
  has_aliases: 'U',
  aliases_array: [],
}

const userBaseState = {
  gender: '',
  birth_date: '',
  shirt_size: ''
}

const baseState = {
  ...userBaseState,
  ...visaBaseState,
}

export default class VisaForm extends Component {
  state = {
    ...Objected.deepClone(baseState),
    completed: false,
    loading: true,
    invalid_birth_date: false,
    invalid_gender: false,
    invalid_shirt_size: false,
  }

  genderOptions = [
    {value: 'M', label: 'Male'},
    {value: 'F', label: 'Female'},
  ]

  get autoComplete() {
    return this._autoComplete = this._autoComplete || `off ${new Date()}`
  }

  get verifying() {
    return !!this.props.verify
  }

  get baseState() {
    return baseState
  }

  get dusId() {
    return this.props.dusId || this.props.dus_id
  }

  get id() {
    return this.props.id || this.dusId
  }

  get name() {
    return this.props.name || 'the passport holder'
  }

  get wrapperClass() {
    return 'list-group-item'
  }

  runComponentDidMount() {
    Component.prototype.componentDidMount.call(this)
  }

  runComponentWillUnmount() {
    Component.prototype.componentWillUnmount.call(this)
  }

  async componentDidMount() {
    this.runComponentDidMount()
    this._baseValues = null
    await this.getDataFromServer()
  }

  componentDidUpdate({ dusId, dus_id }) {
    const id = dusId || dus_id
    if((id !== this.dusId) && this._isMounted) this.setState({loading: true}, this.getDataFromServer)
  }

  action = () => `/api/departure_checklists/${this.id}/verify_details`
  getBaseState = () => Objected.deepClone(this.baseState)
  getFallbackBaseState = () => this.getBaseState()

  getDataFromServer = async () => {
    const bV = this.getBaseState()
    this._baseValues = bV
    try {
      if(this.dusId) {
        const result = await (this._fetchingResource = fetch(this.action())),
              json = await result.json()
        this._baseValues = {...bV, ...Objected.existingOnly(bV, { ...json })['changes']}
        if(this._isMounted) this.setState({ ...json, loading: false })
      } else {
        throw new Error('No ID')
      }
    } catch(err) {
      this._baseValues = bV
      if(this.props.onFail) {
        let msg
        try {
          msg = (await err.response.json()).errors.join(', ')
        } catch(e) {
          msg = err.message
        }
        return this.props.onFail(msg)
      }
      if(this._isMounted) this.setState({...this.getFallbackBaseState(), loading: false})
    }
  }

  getKey = function(event) {
    let val
    try {
      val = (event.currentTarget.name || '').match(/\[([^\]]+)\]$/)[1]
    } catch(_) {
      val = "unknown"
    }
    return val
  }

  onChange = (k, v) => this.setState({[k]: v})
  onTextBlur = (ev) => this.setState({[this.getKey(ev)]: (ev.currentTarget.value || '').toUpperCase()})
  onTextChange = (ev) => this.setState({[this.getKey(ev)]: ev.currentTarget.value || ''})
  onAliasedChange = (v) => this.onChange('has_aliases', v)
  onCitizenshipsChange = (v) => this.onChange('has_multiple_citizenships', v)
  onConvictedChange = (v) => this.onChange('has_convictions', v)
  onArrayChange = (_, {value, key}) => this.onChange(key, value || [])
  onComplete = () => this.props.onComplete && this.props.onComplete()

  onSubmit = (ev) => {
    try {
      ev.preventDefault()
      ev.stopPropagation()
    } catch(_) {}

    this.setState({ loading: true }, async () => {
      try {
        const { changed = false, changes: state } = Objected.existingOnly(this._baseValues || this.baseState, this.state)

        if(!changed) throw new Error("Nothing to Submit")

        this.validateBasic(state)

        this.validateVisa(state)

        const options = {
          method: 'POST',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify({
            passport: Objected.existingOnly(visaBaseState, state).changes || {},
            user: Objected.existingOnly(userBaseState, state).changes || {}
          })
        }

        const result = await fetch(this.action(), options),
                json = await result.json()

        if(json.message === 'ok' || this.verifying) {
          this._baseValues = null
          this.setState({
            ...baseState,
            errors: (json.message === 'ok') ? null : json.errors,
            completed: true,
            loading: false
          }, () => setTimeout(this.onComplete, 2000))
        } else {
          this.setState({ loading: false, errors: [ json.message ] })
        }
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

  validateBasic = state => {
    if(this.props.verified) return true

    if(
        !/^(M|F)$/.test(String(state.gender))
        || !window.confirm(`You have entered that ${this.name} is ${state.gender === 'F' ? 'Female' : 'Male'}. Is that correct?`)
    ) {
      this.setState({ invalid_gender: true })
      throw new Error(
        "You have provided an invalid gender"
      )
    }

    if(
      !/^\d{4}-\d{2}-\d{2}$/.test(String(state.birth_date))
      || !window.confirm(`You have entered that ${this.name} was born on ${dateFns.format(state.birth_date, 'MMMM Do, YYYY')}. Is that correct?`)
    ) {
      this.setState({ invalid_birth_date: true })
      throw new Error(
        "You have provided an invalid birth date"
      )
    }

    if(
        !/^[YA]-\d?[A-Z]{1,2}$/.test(String(state.shirt_size))
        || !window.confirm(`You have entered that ${this.name} wears a ${state.shirt_size.replace('A-', 'Adult ').replace('Y-', 'Youth ')}. Is that correct?`)
    ) {
      this.setState({ invalid_shirt_size: true })
      throw new Error(
        "You have provided an invalid shirt size"
      )
    }
  }

  validateVisa = state => {
    if(state.has_aliases !== 'Y') state.aliases_array = []
    else if(!state.aliases_array || !state.aliases_array.length) {
      throw new Error(
        `You have selected that ${this.name} has aliases, but did not provide details`
      )
    }
    if(state.has_multiple_citizenships !== 'Y') state.citizenships_array = []
    else if(!state.citizenships_array || !state.citizenships_array.length) {
      throw new Error(
        `You have selected that ${this.name} has citizenships, but did not provide details`
      )
    }
    if(state.has_convictions !== 'Y') state.convictions_array = []
    else if(!state.convictions_array || !state.convictions_array.length) {
      throw new Error(
        `You have selected that ${this.name} has convictions, but did not provide details`
      )
    }
  }

  completedMessage = () =>
    <p>
      You will be redirected to the checklist page shortly...
    </p>

  submitSection = () =>
    <div className={this.wrapperClass}>
      { this.submitButtons() }
    </div>

  submitText = () => 'Submit Info'

  submitButtons = (props) =>
    <div className="row">
      <div className="col"></div>
      <div className="col-auto">
        <button type="submit" className='btn btn-primary float-right' {...(props || {})}>
          { this.submitText() }
        </button>
      </div>
    </div>

  renderErrors = () =>
    !!this.state.errors
    && !!this.state.errors.length
    && (
      <div className={this.wrapperClass}>
        <div className="alert alert-danger mb-3 mt-3" role="alert">
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
      </div>
    )

  errorsSection = () => this.renderErrors()

  basicFormFields = () =>
    !this.props.verified
    && <>
      <div className="list-group-item wide-label">
        <InlineRadioField
          name="user[gender]"
          label={<h3 className="text-center">Sex</h3>}
          labelProps={{
            className: 'd-block'
          }}
          options={this.genderOptions}
          value={this.state.gender}
          onChange={(v) => this.onChange('gender', v)}
          required
        />
        {
          this.state.invalid_gender && (
            <div className="mt-3 alert alert-danger" role="alert">
              Please Select {this.name}'s Sex
            </div>
          )
        }
      </div>
      <div className="list-group-item wide-label">
        <CalendarField
          multiText
          required
          closeOnSelect
          allowBlank
          className='form-control'
          name="user[birth_date]"
          label={<h3 className="text-center">Birth Date</h3>}
          type='text'
          pattern={"^\\d{4}-\\d{2}-\\d{2}$"}
          onChange={(e, o) => this.onChange('birth_date', o.value)}
          value={this.state.birth_date}
          size={50}
          calendarStyle={{
            marginBottom: '2rem',
            minWidth: '100%',
          }}
        />
        {
          this.state.invalid_birth_date && (
            <div className="mt-3 alert alert-danger" role="alert">
              Please Select {this.name}'s Date of Birth
            </div>
          )
        }
      </div>
      <div className="list-group-item wide-label">
        <ShirtSizeSelectField
          required
          viewProps={{ className:'form-control', }}
          name="user[shirt_size]"
          label={<h3 className="text-center">Shirt Size</h3>}
          type='text'
          pattern={"^\\d{4}-\\d{2}-\\d{2}$"}
          onChange={(e, o) => this.onChange('shirt_size', o.value)}
          value={this.state.shirt_size}
        />
        {
          this.state.invalid_shirt_size && (
            <div className="mt-3 alert alert-danger" role="alert">
              Please Select {this.name}'s Shirt Size
            </div>
          )
        }
      </div>
    </>

  visaFormFields = () =>
    <>
      <div className={this.wrapperClass}>
        <InlineRadioField
          name="passport[has_convictions]"
          label={`Has ${this.name} ever had a criminal conviction?`}
          value={this.state.has_convictions || 'U'}
          onChange={this.onConvictedChange}
          autoComplete={this.autoComplete}
          required
          options={[
            { value: 'U', label: 'Unknown' },
            { value: 'N', label: 'No' },
            { value: 'Y', label: 'Yes', },
          ]}
        />
        {
          (this.state.has_convictions === 'Y') && (
              <ArrayField
                formKey="convictions_array"
                name="passport[convictions_array]"
                label={`Please list ALL convictions with a summary of the circumstances, each in their own box`}
                feedback='Please list all convictions with a summary of the circumstances'
                sharedProps={{ rows: "5", className: "form-control mb-3" }}
                value={this.state.convictions_array || []}
                onChange={this.onArrayChange}
                autoComplete={this.autoComplete}
                extended
                required
              />
          )
        }
      </div>
      <div className={this.wrapperClass}>
        <InlineRadioField
          name="passport[has_multiple_citizenships]"
          label={`Is ${this.name} a citizen of any other countries?`}
          value={this.state.has_multiple_citizenships || 'U'}
          onChange={this.onCitizenshipsChange}
          autoComplete={this.autoComplete}
          required
          options={[
            { value: 'U', label: 'Unknown' },
            { value: 'N', label: 'No' },
            { value: 'Y', label: 'Yes', },
          ]}
        />
        {
          (this.state.has_multiple_citizenships === 'Y') && (
            <ArrayField
              formKey="citizenships_array"
              name="passport[citizenships_array]"
              label={`Please list ALL countries ${this.name} are a citizen of, each on its own line`}
              value={this.state.citizenships_array || []}
              viewProps={{ className: "form-control form-group" }}
              onChange={this.onArrayChange}
              autoComplete={this.autoComplete}
              required
            />
          )
        }
      </div>
      <div className={this.wrapperClass}>
        <InlineRadioField
          name="passport[has_aliases]"
          label={`Is ${this.name} currently, or has ${this.name} ever been, known by any other names (i.e. aliases)?`}
          value={this.state.has_aliases || 'U'}
          onChange={this.onAliasedChange}
          autoComplete={this.autoComplete}
          required
          options={[
            { value: 'U', label: 'Unknown' },
            { value: 'N', label: 'No' },
            { value: 'Y', label: 'Yes', },
          ]}
        />
        {
          (this.state.has_aliases === 'Y') && (
              <ArrayField
                formKey="aliases_array"
                name="passport[aliases_array]"
                label={`Please list ALL aliases, each on its own line`}
                value={this.state.aliases_array || []}
                viewProps={{ className: "form-control" }}
                onChange={this.onArrayChange}
                autoComplete={this.autoComplete}
                required
              />
          )
        }
      </div>
    </>

  render() {
    console.log(this.state.loading, this.props)
    return this.state.completed ? (
      <div className={this.wrapperClass}>
        <div className="row">
          <div className="col-12">
            <header>
              <h3 className="mt-3 alert alert-success" role="alert">
                Successfully Submitted
              </h3>
            </header>
            { this.props.onComplete && this.completedMessage() }
          </div>
        </div>
      </div>
    ) : (
      <DisplayOrLoading
        display={!this.state.loading}
      >
        {
          this.dusId && (
            <form
              action={this.action()}
              onSubmit={this.onSubmit}
              autoComplete={this.autoComplete}
            >
              { this.errorsSection() }

              { this.basicFormFields() }

              { this.visaFormFields() }

              { this.submitSection() }
            </form>
          )
        }
      </DisplayOrLoading>
    )
  }
}
