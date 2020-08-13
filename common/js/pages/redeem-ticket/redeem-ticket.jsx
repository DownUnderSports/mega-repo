import React from 'react'
import Component from 'common/js/components/component'
import { CardSection, Link } from 'react-component-templates/components';
import { TextField, TextAreaField } from 'react-component-templates/form-components';
import StateSelectField from 'common/js/forms/components/state-select-field'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

const uuidSizing = [
  [ 0, 8 ],
  [ 8, 12 ],
  [ 12, 16 ],
  [ 16, 20 ],
  [ 20, 32 ]
]

const uuidFormat = (val) => {
  const normal = String(val || '').replace(/[^a-zA-Z0-9]/g, "")
  let string = ""
  for (const [start, end] of uuidSizing) {
    if(normal.length >= start) string = string + normal.slice(start, end)
    if(end && normal.length > end) string = string + "-"
    else break
  }

  return string.replace(/-$/, "")
}

export default class RedeemTicketPage extends Component {
  constructor(props){
    super(props)
    this.state = {
      loading: !!(this.ticketId && this.ticketId.length === 36),
      ticket: null
    }
  }

  async componentDidMount(){
    this._isMounted = true
    await this.fetchTicket()
  }

  componentWillUnmount() {
    this._isMounted = false
  }

  componentDidUpdate({ match = {}, location = {} }, state) {

    let refetch = false
    try {
      if(match.params.ticketId !== this.props.match.params.ticketId) {
        this._ticketId = null
        refetch = true
      }
    } catch(_) {
      this._ticketId = null
      refetch = true
    }

    const ticketId = this.ticketId || ''

    let swap = false
    if(ticketId) {
      try {
        if(this.props.match.params.ticketId !== ticketId) swap = true
      } catch(_) {
        swap = true
      }
      if(swap) this.props.history.replace(`/redeem-ticket/${this.ticketId}${this.props.location.search}`)
    }

    if(refetch && !swap) this.fetchTicket()

    try {
      if(location.search !== this.props.location.search) this._dusId = null
    } catch(_) {
      this._dusId = ''
    }

    this._formState = null

    if(this.state.success) setTimeout(() => this._isMounted && this.setState({ success: false, ticket: null, errors: null }, () => this.props.history.replace("/redeem-ticket")), 5000)
  }

  get ticketId() {
    try {
      if(this._ticketId && this._ticketId.length === 36) return this._ticketId
      this._ticketId = uuidFormat(this.props.match.params.ticketId)
    } catch (_) {
      this._ticketId = ''
    }
    return this._ticketId
  }

  get dusId() {
    if(this._dusId) return this._dusId
    try {
      try {
        const params = (new URL(document.location)).searchParams
        for (const [k, v] of params) {
          if(/dus_?[iI]d/.test(String(k))) {
            this._dusId = v
            break
          }
        }
      } catch(_) {
        const search = this.props.location.search || '',
              params = search.replace(/^\?/, '').split('&')
        for (let i = 0; i < params.length; i++) {
          const [k, v] = params[i].split("=")
          if(/dus_?[iI]d/.test(String(k))) {
            this._dusId = v
            break
          }
        }
      }
    } catch (_) {
      this._dusId = ''
    }
    return this._dusId
  }

  get formState() {
    if(this._formState) return this._formState
    const ticket = { },
          address = []

    if(this.state.name) ticket.name = this.state.name
    else { throw new Error("Name is required") }

    if(this.state.phone) ticket.phone = this.state.phone
    else { throw new Error("Phone is required") }

    if(this.state.email) ticket.email = this.state.email
    else { throw new Error("Email is required") }

    if(this.state.street) address.push(this.state.street)
    else { throw new Error("Mailing Address Street(s) are required") }

    if(this.state.city) address.push(this.state.city)
    else { throw new Error("Mailing Address City is required") }

    if(this.state.state) address.push(this.state.state)
    else { throw new Error("Mailing Address State is required") }

    if(this.state.zip) address.push(this.state.zip)
    else { throw new Error("Mailing Address Zip is required") }

    ticket.mailing_address = [address[0], `${address[1]}, ${address[2]} ${address[3]}`].join("\n")
    console.log(ticket)
    this._formState = { ticket }

    return this._formState
  }

  fetchTicket = async () => {
    const ticketId = this.ticketId,
          dusId = this.dusId,
          fetchUrl = `/api/redeem_tickets/${ticketId}${dusId ? `?dus_id=${dusId}` : ''}`
    this.setState({ loading: (ticketId && ticketId.length === 36), errors: null, ticket: null })

    if(ticketId && ticketId.length === 36) {
      try {
        const result = await fetch(fetchUrl),
              { ticket } = await result.json()
        return await this.setStateAsync({ ticket, loading: false })
      } catch(err) {
        return await this.handleError(err, { ticket: null, loading: false })
      }
    }
  }

  handleError = async (err, addState = {}) => {
    try {
      const errorResponse = await err.response.json(),
            athleteName = errorResponse.user || this.state.athleteName
      console.error(err, errorResponse)

      return await this.setStateAsync({
        errors: errorResponse.errors || [ errorResponse.message || errorResponse.error ],
        athleteName,
        ...(addState || {})
      })
    } catch(e) {
      console.error(err)
      return await this.setStateAsync({ errors: [ err.message ], ...(addState || {}) })
    }
  }

  saveTicket = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    try {
      this.card && this.card.scrollIntoView({ behavior: "smooth", block: "start", inline: "start" })
    } catch(_) {
      try {
        this.card && this.card.scrollIntoView(true)
      } catch(_) {
        if(this.card) {
          const scrollTop = this.card.scrollTop
          try {
            (window.scrollTo || window.scroll)(0, scrollTop)
          } catch(_) {}
        }
      }
    }

    this.setState({ loading: true, errors: null, }, async () => {
      const fetchUrl = `/api/redeem_tickets/${this.ticketId}`

      try {
        const result =  await fetch(fetchUrl, {
                method: 'PATCH',
                headers: {
                  "Content-Type": "application/json; charset=utf-8"
                },
                body: JSON.stringify(this.formState)
              }),
              json = await result.json()

        console.log(json)

        return await this.setStateAsync({ success: true, loading: false })
      } catch(err) {
        this.handleError(err)
      }
    })
  }

  onNameChange = (ev) =>
    this.setState({ name: ev.currentTarget.value, nameValidated: true })
  onPhoneChange = (ev) =>
    this.setState({ phone: ev.currentTarget.value, phoneValidated: true })
  onEmailChange = (ev) =>
    this.setState({ email: ev.currentTarget.value, emailValidated: true })
  onStreetChange = (ev) =>
    this.setState({ street: ev.currentTarget.value, streetValidated: true })
  onCityChange = (ev) =>
    this.setState({ city: ev.currentTarget.value, cityValidated: true })
  onStateChange = (_, { abbr: state }) =>
    this.setState({ state , stateValidated: true })
  onZipChange = (ev) =>
    this.setState({ zip: ev.currentTarget.value, zipValidated: true })

  onIdChange = (ev) => {
    this.setState({ errors: null })
    this.props.history.replace(`/redeem-ticket/${ev.currentTarget.value}${this.props.location.search}`)
  }

  renderTicketForm = () => <>
    <div key="ticket-form" className="list-group-item">
      <div className={`row form-group ${this.state.nameValidated ? 'was-validated' : ''}`}>
        <label className="col-5 col-md-4 col-lg-3 col-xl-2 col-form-label" htmlFor="ticket-name">Full Legal Name:</label>
        <div className="col">
          <TextField
            className="form-control"
            name="ticket[name]"
            id="ticket-name"
            value={this.state.name || ""}
            placeholder="John Albert Smith"
            onChange={this.onNameChange}
            autoComplete="name"
            readOnly={this.state.loading || this.state.success}
            skipExtras
            required
          />
        </div>
      </div>
      <div className={`row form-group ${this.state.phoneValidated ? 'was-validated' : ''}`}>
        <label className="col-5 col-md-4 col-lg-3 col-xl-2 col-form-label" htmlFor="ticket-name">Phone:</label>
        <div className="col">
          <TextField
            className="form-control"
            name="ticket[phone]"
            id="ticket-phone"
            placeholder="432-123-4567"
            value={this.state.phone || ""}
            onChange={this.onPhoneChange}
            usePhoneFormat
            inputMode="numeric"
            autoComplete="phone"
            readOnly={this.state.loading || this.state.success}
            skipExtras
            required
          />
        </div>
      </div>
      <div className={`row form-group ${this.state.emailValidated ? 'was-validated' : ''}`}>
        <label className="col-5 col-md-4 col-lg-3 col-xl-2 col-form-label" htmlFor="ticket-name">Email:</label>
        <div className="col">
          <TextField
            className="form-control"
            name="ticket[email]"
            id="ticket-email"
            placeholder="john@smith.com"
            value={this.state.email || ""}
            onChange={this.onEmailChange}
            useEmailFormat
            inputMode="numeric"
            autoComplete="email"
            readOnly={this.state.loading || this.state.success}
            skipExtras
            required
          />
        </div>
      </div>
      <div className={`row form-group ${this.state.streetValidated ? 'was-validated' : ''}`}>
        <label className="col-5 col-md-4 col-lg-3 col-xl-2 col-form-label" htmlFor="ticket-name">Street(s):</label>
        <div className="col">
          <TextAreaField
            className="form-control"
            name="ticket[street]"
            id="ticket-street"
            placeholder="1755 N 400 E, Ste 201"
            value={this.state.street || ""}
            onChange={this.onStreetChange}
            autoComplete="street-address"
            readOnly={this.state.loading || this.state.success}
            skipExtras
            required
          />
        </div>
      </div>
      <div className={`row form-group ${this.state.cityValidated ? 'was-validated' : ''}`}>
        <label className="col-5 col-md-4 col-lg-3 col-xl-2 col-form-label" htmlFor="ticket-name">City:</label>
        <div className="col">
          <TextField
            className="form-control"
            name="ticket[city]"
            id="ticket-city"
            placeholder="North Logan"
            value={this.state.city || ""}
            onChange={this.onCityChange}
            autoComplete="address-level2"
            readOnly={this.state.loading || this.state.success}
            skipExtras
            required
          />
        </div>
      </div>
      <div className={`row form-group ${this.state.stateValidated ? 'was-validated' : ''}`}>
        <label className="col-5 col-md-4 col-lg-3 col-xl-2 col-form-label" htmlFor="ticket-name">State:</label>
        <div className="col">
          <StateSelectField
            className="form-control"
            name="ticket[state]"
            id="ticket-state"
            value={this.state.state || ""}
            onChange={this.onStateChange}
            autoComplete="address-level1"
            readOnly={this.state.loading || this.state.success}
            skipExtras
            required
          />
        </div>
      </div>
      <div className={`row form-group ${this.state.zipValidated ? 'was-validated' : ''}`}>
        <label className="col-5 col-md-4 col-lg-3 col-xl-2 col-form-label" htmlFor="ticket-name">Zip Code:</label>
        <div className="col">
          <TextField
            className="form-control"
            name="ticket[zip]"
            id="ticket-zip"
            value={this.state.zip || ""}
            onChange={this.onZipChange}
            autoComplete="postal-code"
            readOnly={this.state.loading || this.state.success}
            skipExtras
            required
          />
        </div>
      </div>
    </div>
    <div key="form-privacy" className="list-group-item">
      <h5 className="text-center">
        Thank You Ticket Redemption Privacy Policy
      </h5>
      <ul>
        <li>
          Any information given through this form will <b>only</b> be used to
          notify you about the Travel Giveaway.
        </li>
        <li>
          We will never use the information provided to contact you for any
          other reason.
        </li>
        <li>
          Providing incorrect or falsified information may result in your entry
          being void.
        </li>
      </ul>
    </div>
    <div key="submit-form" className="list-group-item">
      <button disabled={this.state.loading || this.state.success} onClick={this.saveTicket} className="btn btn-block btn-primary">
        Submit Entry
      </button>
    </div>
  </>

  renderErrors = () =>
    !!this.state.errors
    && !!this.state.errors.length
    && (
      <div key="errors" className="list-group-item">
        <div className="alert alert-danger form-group" role="alert">
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

  enterIdForm = () =>
    <div className="list-group-item">
      <TextField
        label="Ticket ID (will be automatically formatted)"
        className="form-control"
        name="ticket[id]"
        id="ticket-id"
        value={this.ticketId || ""}
        onChange={this.onIdChange}
        autoComplete="off"
        placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        caretIgnore="-"
      />
    </div>

  cardRef = (el) => this.card = el

  render() {
    const { ticket } = this.state
    if(this.state.loading) return <JellyBox className="page-loader" />
    return (
      <>
        <CardSection
          key="main-section"
          wrapperRef={this.cardRef}
          className="RedeemTicketPage my-4"
          label={<div>
            Redeem a Thank You Ticket
          </div>}
          contentProps={{className: 'list-group'}}
        >
          {
            !!this.state.success && <div className="list-group-item">
              <div className="alert alert-success form-group" role="alert">
                SUCCESS! This form will be automatically reset within 5 seconds
              </div>
            </div>
          }
          { this.renderErrors() }
          {
            !!ticket
              ? this.renderTicketForm()
              : this.enterIdForm()
          }
        </CardSection>
        <Link
          key="terms-link"
          to="/travel-giveaways"
          target="_terms"
          className="d-block my-3 text-center"
        >
          Click Here to view the Down Under Sports Travel Giveaway Rules
        </Link>
      </>
    );
  }
}
