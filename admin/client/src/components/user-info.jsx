import React, { Component, Fragment } from 'react';
import { DisplayOrLoading, CardSection, Link } from 'react-component-templates/components';
import UserForm from 'forms/user-form'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import dateFns from 'date-fns'


export const usersUrl = '/admin/users/:id.json'

const pnrUrl = '/admin/traveling/flights/schedules'
const busUrl = '/admin/traveling/ground_control/buses'

export default class UserInfo extends Component {
  static genders = {
    f: 'Female',
    F: 'Female',
    m: 'Male',
    M: 'Male',
    u: 'Unknown',
    U: 'Unknown'
  }

  get nonRefundableAmount() {
    try {
      const { user: { traveler: { departing_date: departingDate = '2001-01-01' }, total_payments: totalPayments = 0 } } = this.state,
            distance = dateFns.differenceInCalendarDays(
              dateFns.parse(departingDate),
              new Date()
            )
      let maxNonRefundable
      if(distance > 95) {
        maxNonRefundable = 30000
      } else if (distance > 70) {
        maxNonRefundable = 130000
      } else if (distance > 45) {
        maxNonRefundable = 230000
      } else {
        maxNonRefundable = totalPayments
      }
      return `$${Math.round((Number(Math.min(totalPayments, maxNonRefundable)) + 0.00001)) / 100}`
    } catch(_) {
      return ''
    }
  }

  get middleName() {
    return this.state.user.middle ? ` ${this.state.user.middle}` : ''
  }

  get suffixName() {
    return this.state.user.suffix ? ` ${this.state.user.suffix}` : ''
  }

  get printName() {
    if(!this.state.user) return ''
    return `${
      this.state.user.print_first_names || `${this.state.user.first}${this.middleName}`
    } ${
      this.state.user.print_other_names || `${this.state.user.last}${this.suffixName}`
    }`
  }

  get fullName() {
    if(!this.state.user) return ''
    return `${
      this.state.user.title
    } ${
      this.state.user.first
    } ${
      this.state.user.middle
    } ${
      this.state.user.last
    } ${
      this.state.user.suffix
    }`
  }

  constructor(props) {
    super(props)
    this.state = { user: {}, fullStats: false, reloading: !!this.props.id, showForm: !this.props.id, showInterestHistory: false }
  }

  async componentDidMount(){
    if(this.props.id) await this.getUser()
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.getUser()
  }

  componentWillUnmount() {
    this._unmounted = true
    this.abortFetch()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  forceGetUser = () => this.getUser(this.state.showForm, true)

  getUser = async (showForm = false, force = false) => {
    if(this._unmounted) return false
    if(!this.props.id) return this.setState({showForm})
    this.setState({reloading: true})
    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('UserInfo: No User ID')
      this._fetchable = fetch(`${usersUrl.replace(':id', this.props.id)}?force=${force ? 1 : 0}`, {timeout: 5000})
      const result = await this._fetchable,
            user = await result.json()

      this._unmounted || this.setState({
        reloading: false,
        user,
        showForm
      })

      if(this.props.afterFetch) this.props.afterFetch({ user })
    } catch(e) {
      console.error(e)
      this._unmounted || this.setState({
        reloading: false,
        user: {},
      })
    }
  }

  openUserForm = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.getUser(true)
  }

  toggleInterestHistories = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.setState({ showInterestHistory: !this.state.showInterestHistory })
  }

  requestInfokit = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.setState({reloading: true})
    try {
      const has_infokit = !!this.state.user.has_infokit
      if(!has_infokit || window.confirm('Are you sure you want to resend this infokit?')) {
        await fetch(`${usersUrl.replace(':id', `${this.props.id}/infokit`)}${has_infokit ? '?force=true' : ''}`)
        await this.getUser()
      } else {
        throw new Error('Already Requested')
      }
    } catch(e) {
      console.error(e)
      this._unmounted || this.setState({
        reloading: false,
      })
    }
  }

  cancelUser = async (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    if(!this.state.user) return false
    if(this.state.user.interest_id === 1) return alert('You must set an appropriate interest level first')
    if(window.confirm(`Are you sure you want to cancel ${this.fullName}?`)) {
      try {
        this.setState({reloading: true})
        await fetch(usersUrl.replace(':id', `${this.props.id}/cancel`), {
          method: 'DELETE',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify({
            cancel: true
          })
        });

        await this.getUser()
      } catch (err) {
        this._unmounted || this.setState({reloading: false})
        try {
          const resp = await err.response.json()
          console.log(resp)
          alert(resp.error)
        } catch(e) {
          alert(e.message)
        }
      }
    }
  }

  markTravelPrep = async (ev, category, message) => {
    ev.preventDefault()
    ev.stopPropagation()
    if(!this.state.user) return false
    if(window.confirm(`Are you sure you want to mark ${message.replace(/FULL_NAME/g, this.fullName).replace(/PRINT_NAME/g, this.printName)}?`)) {
      try {
        this.setState({reloading: true})
        await fetch(usersUrl.replace(':id', `${this.props.id}/travel_preparation`), {
          method: 'PATCH',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify({ category })
        });

        await this.getUser()
      } catch (err) {
        this._unmounted || this.setState({reloading: false})
        try {
          const resp = await err.response.json()
          console.log(resp)
          alert(resp.error)
        } catch(e) {
          alert(e.message)
        }
      }
    }
  }

  confirmAddress = ev => this.markTravelPrep(ev, 'address_confirmed_date', 'Address as Confirmed Correct')
  confirmDOB = ev => this.markTravelPrep(ev, 'dob_confirmed_date', 'Birth Date is Correct')
  confirmName = ev => this.markTravelPrep(ev, 'name_confirmed_date', 'FULL_NAME as their confirmed correct legal name')
  confirmPrintName = ev => this.markTravelPrep(ev, 'print_name_confirmed_date', 'PRINT_NAME as their confirmed preferred name for all public and printed media')
  joinedFollowup = ev => this.markTravelPrep(ev, 'joined_team_followup_date', 'that you have completed the first followup with FULL_NAME after they joined the team')
  domesticFollowup = ev => this.markTravelPrep(ev, 'domestic_followup_date', 'that you have explained Additional Airfare to FULL_NAME')
  insuranceFollowup = ev => this.markTravelPrep(ev, 'insurance_followup_date', 'that you have explained insurance to FULL_NAME')
  checklistFollowup = ev => this.markTravelPrep(ev, 'checklist_followup_date', 'that you have explained how to use the departure checklist to FULL_NAME')
  receivedFrPkt = ev => this.markTravelPrep(ev, 'fundraising_packet_received_date', 'FULL_NAME has received their fundraising packet')
  receivedTrvlPkt = ev => this.markTravelPrep(ev, 'travel_packet_received_date', 'FULL_NAME has received their final travel packet')
  appliedForPP = ev => this.markTravelPrep(ev, 'applied_for_passport_date', 'FULL_NAME has applied for their passport')
  appliedForETA = ev => this.markTravelPrep(ev, 'applied_for_eta_date', 'FULL_NAME has applied for their OWN ETA')

  phoneFormat(phone) {
    phone = String(phone || '')
    switch (true) {
      case /^\+/.test(phone):
        return phone
      case /^0/.test(phone):
        return `+61${phone.replace(/^0|[^0-9]/g, '')}`
      case /^[0-9]{3}-?[0-9]{3}-?[0-9]{4}$/.test(phone):
        return `+1-${phone}`;
      default:
        return phone
    }
  }

  render() {
    const {
      user: {
        avatar_attached = false,
        avatar,
        address,
        athlete = {},
        coach = {},
        official = {},
        dus_id,
        email,
        ambassador_emails = [],
        // first,
        gender,
        has_infokit,
        // last,
        // middle,
        phone,
        ambassador_phones = [],
        // print_first_names,
        // print_other_names,
        // suffix,
        // title,
        interest_level,
        interest_histories = [],
        contactable,
        traveler,
        ground_only,
        team,
        shirt_size,
        birth_date,
        join_date,
        staff_page = false,
        competing_team_list = '',
        pnrs = [],
        buses = [],
        travel_preparation_attributes = {}
      },
      fullStats = false,
      reloading = false,
      showForm,
      showInterestHistory
    } = this.state || {}

    const travel_preparation = travel_preparation_attributes || {}

    return (
      <DisplayOrLoading
        display={!reloading}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        {
          showForm ? (
            <UserForm
              key={this.props.formId || dus_id || 'new'}
              id={ this.props.formId || dus_id }
              onSuccess={ this.props.onSuccess || (() => this.getUser()) }
              onCancel={ this.props.onCancel || (() => this.setState({showForm: false}))}
              url={ this.props.url || '' }
              user={{
                ...(this.state.user || {}),
                relationship: this.props.relationship || '',
              }}
              showRelationship={!!(this.props.relationship || this.props.showRelationship)}
            />
          ) : (
            <CardSection
              className={`mb-3 ${!contactable && 'alert-danger'} ${traveler && !traveler.cancel_date && 'alert-success'}`}
              label={
                <div className="row">
                  <div className="col-auto">
                    <Link onClick={this.openUserForm} to={window.location.href}>Edit</Link>
                  </div>
                  <div className="col">
                    <div className="d-flex justify-content-center">
                      <span>{this.props.header || 'User Info'}</span>
                      <i className="ml-3 material-icons clickable" onClick={this.forceGetUser}>
                        refresh
                      </i>
                    </div>
                  </div>
                  <div className="col-auto">
                    <Link to={`/admin/users/${dus_id}`}>{dus_id}</Link>
                  </div>
                </div>
              }
              contentProps={{className: 'list-group'}}
            >
              {
                (avatar_attached || (traveler && ground_only)) && (
                  <div className="list-group-item">
                    <div className="row">
                      <div className="col-md col-12">
                        {
                          avatar_attached && (
                            <Fragment>
                              <Link to={avatar} target="_user_avatar">
                                View Sponsor Photo
                              </Link>
                              <hr className='d-md-none'/>
                            </Fragment>
                          )
                        }
                      </div>
                      {
                        traveler && (
                          <div className="col-md col-12 text-right">
                            { ground_only && <strong className="text-danger">IS GROUND ONLY</strong> }
                          </div>
                        )
                      }
                    </div>
                  </div>
                )
              }
              <div className="list-group-item">
                <div className="row">
                  <div className="col-md col-12">
                    <strong>Full Name:</strong> { this.fullName }
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong>Print Names:</strong> { this.printName }
                  </div>
                </div>
              </div>
              <div className="list-group-item">
                <div className="row">
                  <div className="col-md col-12">
                    <strong className="no-wrap">Name Confirmed:</strong>
                    <div className="no-wrap">
                      {
                        travel_preparation.name_confirmed_date
                        ||  <button type="button" className='btn btn-warning' onClick={this.confirmName}>
                              Confirm Legal Name
                            </button>
                      }
                    </div>
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong className="no-wrap">Print Name Confirmed:</strong>
                    <div className="no-wrap">
                      {
                        travel_preparation.print_name_confirmed_date
                        ||  <button type="button" className='btn btn-warning' onClick={this.confirmPrintName}>
                              Confirm Printed Name
                            </button>
                      }
                    </div>
                  </div>
                </div>
              </div>
              <div className="list-group-item">
                <div className="row">
                  <div className="col-md col-12">
                    <strong>Email:</strong> <a href={`mailto:${email}`}>{email}</a>
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong>Phone:</strong> <a href={`tel:${this.phoneFormat(phone)}`}>{phone}</a>
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong>Gender:</strong> {this.constructor.genders[gender] || 'Unknown'}
                  </div>
                </div>
              </div>
              <div className="list-group-item">
                <div className="row">
                  <div className="col">
                    <strong>Address:</strong> {address}
                  </div>
                </div>
              </div>
              <div className="list-group-item">
                <div className="row">
                  <div className="col-md col-12">
                    <strong className="no-wrap">Address Confirmed:</strong>&nbsp;
                    {
                      address
                      &&  (address !== 'No Address')
                      &&  <span className="no-wrap">
                            {
                              travel_preparation.address_confirmed_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.confirmAddress}>
                                    Confirm Address
                                  </button>
                            }
                          </span>
                    }
                  </div>
                </div>
              </div>
                {
                  showInterestHistory
                    ? (
                      <table className="table" onClick={this.toggleInterestHistories}>
                        <thead>
                          <tr>
                            <th className="text-center" colSpan="3">
                              Interest Level History
                              <i className="material-icons float-right">
                                arrow_drop_up
                              </i>
                            </th>
                          </tr>
                          <tr>
                            <th>
                              Level
                            </th>
                            <th>
                              Set At
                            </th>
                            <th>
                              Set By
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          {
                            Array.isArray(interest_histories) && interest_histories
                              .map((history, idx) => {
                                const date = dateFns.parse(history.changed_at)
                                return <tr key={history.id}>
                                  <td>
                                    { history.interest_level } { !idx && "(Current)" }
                                  </td>
                                  <td>
                                    <span
                                      className="tooltip-nowrap tooltip-underline tooltip-right tooltip-legible pointer"
                                      data-tooltip={dateFns.format(date, 'dddd, MMM Do, YYYY HH:mm:ss.SSS')}
                                    >
                                      { dateFns.format(date, 'MM/DD/YYYY h:mm A') }
                                    </span>
                                  </td>
                                  <td>
                                    { history.changed_by || "Unknown" }
                                  </td>
                                </tr>
                              })
                          }
                        </tbody>
                      </table>
                    )
                  : (
                    <div className="list-group-item clickable" onClick={this.toggleInterestHistories}>
                      <strong key="label">Interest:</strong> {interest_level}
                      <i className="material-icons float-right">
                        arrow_drop_down
                      </i>
                    </div>
                  )
                }
              <div className="list-group-item">
                <div className="row">
                  {
                    traveler ? (
                      <Fragment>
                        <div className="col-md col-12">
                          <strong>Joined:</strong> {join_date}
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong>Active:</strong> {traveler.cancel_date ? 'NO' : 'YES'}
                          <hr className='d-md-none'/>
                        </div>
                        {
                          traveler.cancel_date ? (
                            <div className="col-md col-12">
                              <strong>Cancel Date:</strong> <br/>
                              <span className="no-wrap">{ traveler.cancel_date }</span>
                            </div>
                          ) : (
                            <div className="col-md col-12">
                              <strong className="no-wrap">Cancel User:</strong><br/>
                              <button type="button" className='btn btn-danger' onClick={this.cancelUser}>
                                Cancel User
                              </button>
                            </div>
                          )
                        }
                      </Fragment>
                    ) : ''
                  }
                </div>
              </div>
              {
                traveler && (
                  <>
                    <div className="list-group-item">
                      <div className="row">
                        <div className="col-md col-12">
                          <strong className="no-wrap">Joined Followup:</strong>
                          <div className="no-wrap">
                            {
                              travel_preparation.joined_team_followup_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.joinedFollowup}>
                                    Followed Up
                                  </button>
                            }
                          </div>
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong className="no-wrap">Airfare Followup:</strong>
                          <div className="no-wrap">
                            {
                              travel_preparation.domestic_followup_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.domesticFollowup}>
                                    Followed Up
                                  </button>
                            }
                          </div>
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong className="no-wrap">Insurance Followup:</strong>
                          <div className="no-wrap">
                            {
                              travel_preparation.insurance_followup_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.insuranceFollowup}>
                                    Followed Up
                                  </button>
                            }
                          </div>
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong className="no-wrap">Checklist Followup:</strong>
                          <div className="no-wrap">
                            {
                              travel_preparation.checklist_followup_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.checklistFollowup}>
                                    Followed Up
                                  </button>
                            }
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="list-group-item">
                      <div className="row">
                        <div className="col-md col-12">
                          <strong className="no-wrap">Fr Pkt Rcvd:</strong>
                          <div className="no-wrap">
                            {
                              travel_preparation.fundraising_packet_received_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.receivedFrPkt}>
                                    Mark Date
                                  </button>
                            }
                          </div>
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong className="no-wrap">Trvl Pkt Rcvd:</strong>
                          <div className="no-wrap">
                            {
                              travel_preparation.travel_packet_received_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.receivedTrvlPkt}>
                                    Mark Date
                                  </button>
                            }
                          </div>
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong className="no-wrap">Applied for PP:</strong>
                          <div className="no-wrap">
                            {
                              travel_preparation.applied_for_passport_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.appliedForPP}>
                                    Mark Date
                                  </button>
                            }
                          </div>
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong className="no-wrap">Applied for Own ETA:</strong>
                          <div className="no-wrap">
                            {
                              travel_preparation.applied_for_eta_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.appliedForETA}>
                                    Mark Date
                                  </button>
                            }
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="list-group-item">
                      <div className="row">
                        <div className="col-md col-12">
                          <strong>Departing:</strong> {traveler.departing_dates}
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong>Returning:</strong> {traveler.returning_dates}
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong>Non-Refundable:</strong> {this.nonRefundableAmount}
                        </div>
                      </div>
                    </div>
                    {
                      !!Object.keys(travel_preparation.deadlines || {}).length
                      && (
                        <div className="list-group-item">
                          <strong>Rollover Deadline:</strong> {
                            travel_preparation.rollover_deadline
                              ? dateFns.format(travel_preparation.rollover_deadline, 'MMMM Do')
                              : 'N/A'
                          }
                        </div>
                      )
                    }
                    <div className="list-group-item">
                      <div className="row">
                        <div className="col">
                          <strong>PNRs</strong>: {
                            pnrs.map(
                              (pnr, i) =>
                                <span key={pnr}>
                                  { i > 0 && <span>, &nbsp;</span> }
                                  <Link
                                    key={pnr}
                                    to={`${pnrUrl}/${pnr}`}
                                  >
                                    {pnr}
                                  </Link>
                                </span>
                            )
                          }
                        </div>
                      </div>
                    </div>
                    <div className="list-group-item">
                      <div className="row">
                        <div className="col">
                          <strong>Buses</strong>: {
                            buses.map(
                              ({ id, color, text }, i) =>
                                <span key={id}>
                                  {i > 0 && <span>; &nbsp;</span>}
                                  <Link
                                    key={id}
                                    to={`${busUrl}/${id}`}
                                    className={`text-colored ${color}`}
                                  >
                                    { text }
                                  </Link>
                                </span>
                            )
                          }
                        </div>
                      </div>
                    </div>
                  </>

                )
              }
              {
                !!((ambassador_emails || []).length) && (
                  <div className="list-group-item">
                    <strong><a href={`mailto:${ambassador_emails.join(';')}`}>Ambassador Emails</a>:</strong> {ambassador_emails.map(e => e && ( <a key={e} href={`mailto:${e}`}>{e}</a> ))}
                  </div>
                )
              }
              {
                !!((ambassador_phones || []).length) && (
                  <div className="list-group-item">
                    <strong>Ambassador Phones:</strong> {ambassador_phones.map(p => p && (<a key={p} href={`tel:${p}`}>{p}</a>))}
                  </div>
                )
              }
              <div className="list-group-item">
                <div className="row">
                  {
                    (team || {}).name ? (
                      <div className="col-md col-12">
                        <strong>Team:</strong> {team.name}
                        <hr className='d-md-none'/>
                      </div>
                    ) : ''
                  }
                  <div className="col-md col-12">
                    <strong>Shirt Size:</strong> {shirt_size}
                  </div>
                </div>
              </div>
              <div className="list-group-item">
                <div className="row">
                  <div className="col-md col-12">
                    <strong>Birth Date:</strong> {birth_date}
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong className="no-wrap">DOB Confirmed:</strong>&nbsp;
                    {
                      !!birth_date
                      &&  <span className="no-wrap">
                            {
                              travel_preparation.dob_confirmed_date
                              ||  <button type="button" className='btn btn-warning' onClick={this.confirmDOB}>
                                    Confirm DOB
                                  </button>
                            }
                          </span>
                    }
                  </div>
                </div>
              </div>
              {
                competing_team_list && (
                  <div className="list-group-item">
                    <strong>Competing Teams:</strong> { competing_team_list }
                  </div>
                )
              }

              {
                athlete.school_name ? (
                  <Fragment>
                    <div className="list-group-item">
                      <strong>School:</strong> {athlete.school_name}
                    </div>
                    <div className="list-group-item">
                      <strong>Grad:</strong> {athlete.year_grad}
                    </div>
                    <div className="list-group-item">
                      <strong>Source:</strong> {athlete.source_name}
                    </div>
                    <div className="list-group-item">
                      <strong>Sport:</strong> {athlete.sport_abbr}
                    </div>
                    {
                      athlete.main_event && (
                        <div className="list-group-item">
                          <strong>Main Event:</strong> {athlete.main_event} {`(${athlete.main_event_best})`}
                        </div>
                      )
                    }
                    {
                      athlete.stats && (
                        <div className="list-group-item" onClick={() => this.setState({fullStats: !fullStats})}>
                          <strong>Stats:</strong><br/>
                          <pre style={(fullStats ? null : {maxWidth: '40vw', overflow: 'hidden'})}>{athlete.stats}</pre>
                        </div>
                      )
                    }
                  </Fragment>
                ) : (
                  coach.school_name ? (
                    <Fragment>
                      <div className="list-group-item">
                        <strong>School:</strong> {coach.school_name}
                      </div>
                      <div className="list-group-item">
                        <strong>Deposits:</strong> {coach.deposits}
                      </div>
                      <div className="list-group-item">
                        <strong>Background Checked?:</strong> {coach.checked_background ? 'Yes' : 'No'}
                      </div>
                    </Fragment>
                  ) : (
                    official.category ? (
                      <Fragment>
                        <div className="list-group-item">
                          <strong>Type of Official:</strong> {official.category}
                        </div>
                      </Fragment>
                    ) : ''
                  )
                )
              }
              {
                dus_id && !staff_page ? (
                  <div className='row'>
                    <div className="col">
                      <button className='btn-block btn-primary' onClick={this.requestInfokit}>
                        {
                          has_infokit ? 'Resend IK Email' : 'Send Infokit'
                        }
                      </button>
                    </div>
                  </div>
                ) : ''
              }
            </CardSection>
          )
        }
      </DisplayOrLoading>
    );
  }
}
