import React, { Component, Fragment } from 'react';
import { DisplayOrLoading, CardSection, Link } from 'react-component-templates/components';
//import authFetch from 'common/js/helpers/auth-fetch'
import canUseDOM from 'common/js/helpers/can-use-dom'
import UserForm from 'forms/user-form'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import dateFns from 'date-fns'


export const usersUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/users/:id.json`

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

  constructor(props) {
    super(props)
    this.state = { user: {}, fullStats: false, reloading: !!this.props.id, showForm: !this.props.id }
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

  getUser = async (showForm = false) => {
    if(this._unmounted) return false
    if(!this.props.id) return this.setState({showForm})
    this.setState({reloading: true})
    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('UserInfo: No User ID')
      this._fetchable = fetch(usersUrl.replace(':id', this.props.id), {timeout: 5000})
      const result = await this._fetchable,
            retrieved = await result.json()

      this._unmounted || this.setState({
        reloading: false,
        user: retrieved,
        showForm
      })

      if(this.props.afterFetch) this.props.afterFetch({user: retrieved})
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
    if(window.confirm(`Are you sure you want to cancel ${this.state.user.title} ${this.state.user.first} ${this.state.user.middle} ${this.state.user.last} ${this.state.user.suffix}?`)) {
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
        first,
        gender,
        has_infokit,
        last,
        middle,
        phone,
        ambassador_phones = [],
        print_first_names,
        print_other_names,
        suffix,
        title,
        interest_level,
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
      },
      fullStats = false,
      reloading = false,
      showForm
    } = this.state || {}

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
              label={<div>
                <Link className='float-left' onClick={this.openUserForm} to={window.location.href}>Edit</Link>
                {this.props.header || 'User Info'}
                <Link className='float-right' to={`/admin/users/${dus_id}`}>{dus_id}</Link>
              </div>}
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
                    <strong>Interest:</strong> {interest_level}
                    {
                      traveler ? (
                        <hr className='d-md-none'/>
                      ) : ''
                    }
                  </div>
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
                              <strong>Cancel Date:</strong> { traveler.cancel_date }
                            </div>
                          ) : (
                            <div className="col-md col-12">
                              <strong>Cancel User:</strong>&nbsp;&nbsp;<button type="button" className='btn btn-danger' onClick={this.cancelUser}>
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
                          <strong>Departing:</strong> {dateFns.format(traveler.departing_date, 'MMMM Do')}
                          <hr className='d-md-none'/>
                        </div>
                        <div className="col-md col-12">
                          <strong>Returning:</strong> {dateFns.format(traveler.returning_date, 'MMMM Do')}
                        </div>
                        <div className="col-md col-12">
                          <strong>Non-Refundable:</strong> {this.nonRefundableAmount}
                        </div>
                      </div>
                    </div>
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
              <div className="list-group-item">
                <div className="row">
                  <div className="col-md col-12">
                    <strong>Full Name:</strong> {title} {first} {middle} {last} {suffix}
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong>Print Names:</strong> {print_first_names || `${title} ${first}` } { print_other_names || `${middle} ${last} ${suffix}` }
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
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong>Birth Date:</strong> {birth_date}
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
              <div className="list-group-item">
                <div className="row">
                  <div className="col">
                    <strong>Address:</strong> {address}
                  </div>
                </div>
              </div>
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
