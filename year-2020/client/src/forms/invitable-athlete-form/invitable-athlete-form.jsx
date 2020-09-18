import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading, CardSection, Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { SelectField } from 'react-component-templates/form-components';


const defaults = {
        athlete_id: '',
        attributes: {},
        gender: '',
        grad: '',
        sport: '',
        stats: '',
        transferability: '',
        user_id: '',
      },
      selectViewProps = { className: "form-control" },
      selectOptions = [
        {
          value: '',
          label: '-- SELECT ONE --',
          disabled: true
        },
        {
          value: 'always',
          label: 'Always Invite',
        },
        {
          value: 'necessary',
          label: 'Only Invite When Needed',
        },
        {
          value: 'none',
          label: 'Never Invite',
        },
      ]

export default class InvitableAthleteForm extends Component {
  constructor(props) {
    super(props)

    const athlete = Objected.deepClone(defaults)

    this.state = {
      loaded: false,
      errors: null,
      athlete
    }
  }

  get action() {
    return `/admin/cleanups/${this.props.id}`
  }

  componentDidMount(){
    this._unmounted = false
    this.loadData()
  }

  componentWillUnmount(){
    this._unmounted = true
    this.abortFetch()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  loadData = () => {
    if(this._unmounted) return false
    this.abortFetch()
    this.setState({ loaded: false, submitting: false }, this.getData)
  }

  getData = async () => {
    if(this._unmounted) return false
    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('No ID Given')
      this._fetchable = fetch(this.action, {timeout: 5000})
      const result = await this._fetchable,
            athlete = await result.json()

      this._unmounted || this.setState({
        loaded: true,
        athlete,
      })
    } catch(err) {
      this.onError(err, 'loaded')
    }
  }

  onError = async (err, submitOrLoad = "submitting") => {
    console.error(err)
    if(this._unmounted) return false
    try {
      let errors = (await err.response.json()).errors
      if(!Array.isArray(errors)) errors = [ errors ]
      this.setState({ errors, [submitOrLoad]: false })
    } catch(_err) {
      this.setState({ errors: [ err.message ], [submitOrLoad]: false })
    }
  }

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({ submitting: true })
    this.handleSubmit()
  }

  handleSubmit = async () => {
    try {
      const { transferability } = this.state.athlete

      if(!transferability) throw new Error('Cannot Save Nothing')

      const result = await fetch(this.action, {
        method: 'PATCH',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ athletes_sport: { transferability } })
      });

      await result.json();

      await (this.props.onSuccess || this.loadData)(transferability)
    } catch(err) {
      this.onError(err, 'submitting')
    }
  }

  onTransferabilityChange = (_, { value }) => {
    this.setState((state, _) => {
      const athlete = Objected.deepClone(state.athlete || defaults)
      athlete.transferability = String(value || '')
      return { athlete }
    })
  }

  gender(gender) {
    if(gender === 'M') return 'Male'
    if(gender === 'F') return 'Female'
    return 'Unknown'
  }

  render(){
    const {
      loaded,
      submitting,
      athlete = {},
      errors = null
    } = this.state

    const display = loaded && !submitting,
          errorsRender = !!errors && (
            <div className="alert alert-danger form-group" role="alert">
              {
                errors.map((v, k) => (
                  <div className='row' key={k}>
                    <div className="col">
                      { v }
                    </div>
                  </div>
                ))
              }
            </div>
          )

    if(!display && errors) return errorsRender

    return (
      <DisplayOrLoading
        display={display}
        loadingElement={
          <JellyBox className="page-loader" />
        }
      >
        <CardSection
          className='mb-3'
          label={
            <div className="row">
              <div className="col-auto"></div>
              <div className="col">Invitation Criteria for {athlete.sport} Athlete</div>
              <div className="col-auto">
                <i className="material-icons clickable" onClick={this.loadData}>
                  refresh
                </i>
              </div>
            </div>
          }
        >
          <form
            action={this.action}
            method='post'
            className='invitable-athlete-form'
            onSubmit={this.onSubmit}
            autoComplete="off"
          >
            <input autoComplete="false" type="text" name="autocomplete" style={{display: 'none'}}/>
            <div className="row">
              <div className="col">
                { errorsRender }
              </div>
            </div>
            <div className="row form-group">
              <div className="col-12 form-group d-md-none">
                <a
                  href={`/admin/users/${athlete.user_id}`}
                  className="btn btn-block btn-info"
                  target="_show_user"
                >
                  View Full Page
                </a>
              </div>
              <div className="col">
                <ul>
                  <li>
                    <strong>Sport:</strong> {athlete.sport}
                  </li>
                  <li>
                    <strong>Gender:</strong> { this.gender(athlete.gender) }
                  </li>
                  <li>
                    <strong>Grad:</strong> {athlete.grad || 'Unknown'}
                  </li>
                  {
                    !!athlete.attributes.height && (
                      <li>
                        <strong>Height:</strong> {athlete.attributes.height}
                      </li>
                    )
                  }
                  {
                    !!athlete.attributes.handicap && (
                      <li>
                        <strong>Handicap:</strong> {athlete.attributes.handicap}
                      </li>
                    )
                  }
                  {
                    !!athlete.attributes.main_event && (
                      <li>
                        <strong>Main Event:</strong> {athlete.attributes.main_event} <br/>
                        &mdash; <strong>Best:</strong> {athlete.attributes.main_event_best}
                      </li>
                    )
                  }
                  {
                    !!athlete.attributes.positions_array
                      && !!athlete.attributes.positions_array.length
                      && (
                      <li>
                        <strong>Positions:</strong> {athlete.attributes.positions_array.join(",")}
                      </li>
                    )
                  }
                </ul>
              </div>
              <div className="col">
                <strong>Stats:</strong>
                <pre>{athlete.stats}</pre>
              </div>
            </div>
            <hr/>
            <div className="row">
              <div className="col-md d-none d-md-block">
                <a
                  href={`/admin/users/${athlete.user_id}`}
                  className="btn btn-block btn-info"
                  target="_show_user"
                >
                  View Full Page
                </a>
              </div>
              <div className="col-md">
                <div className="form-group">
                  <SelectField
                    viewProps={selectViewProps}
                    options={selectOptions}
                    name="athlete.transferability"
                    value={athlete.transferability}
                    onChange={this.onTransferabilityChange}
                    skipExtras
                  />
                </div>
                <button
                  type="submit"
                  onClick={this.onSubmit}
                  className="btn btn-block btn-primary"
                >
                  Submit
                </button>
              </div>
            </div>
            {
              !!athlete.standard && (
                <div>
                  <hr/>
                  <Link
                    to={athlete.standard}
                    className="btn btn-info btn-block btn-warning mb-1"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Open {athlete.sport} Standards in New Tab
                  </Link>
                  <object
                    data={athlete.standard}
                    width="100%"
                    height="500"
                    type="application/pdf"
                    className="mb-1 vh-75"
                  >
                    <object
                      data={`https://docs.google.com/viewer?embedded=true&url=${athlete.standard}`}
                      width="100%"
                      height="500"
                      className="mb-1 vh-75"
                    >
                      <p>
                        Your Browser Does Not Support Embedded PDFs
                      </p>
                    </object>
                  </object>
                </div>
              )
            }
          </form>
        </CardSection>
      </DisplayOrLoading>
    )
  }
}
