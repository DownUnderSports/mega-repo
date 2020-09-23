import React, { Component } from "react";
import { CardSection, DisplayOrLoading, Link } from "react-component-templates/components"
import Avatar from "components/user-avatar"
import AmbassadorInfo from "components/ambassador-info"
import BenefitsUploadForm from "forms/benefits-upload-form"
import CheckPaymentForm from "forms/check-payment-form"
import ContactAttempts from "components/user-contact-attempts"
import ContactHistories from "components/user-contact-history"
import FlightsUploadForm from "forms/flights-upload-form"
import FundraisingPacketUploadForm from "forms/fundraising-packet-upload-form"
import IncentiveDeadlinesUploadForm from "forms/incentive-deadlines-upload-form"
import InsuranceUploadForm from "forms/insurance-upload-form"
import LegalUploadForm from "forms/legal-upload-form"
import Mailings from "components/user-mailings"
import MeetingRegistrations from "components/meeting-registrations"
import Notes from "components/user-notes"
import PassportForm from "forms/passport-form"
import PaymentForm from "common/js/forms/payment-form"
import Printing from "components/user-printing"
import Requests from "components/requests"
import TransferExpectationForm from "forms/transfer-expectation-form"
import UserInfo from "components/user-info"
import UserRelations from "components/user-relations"
import VideoViews from "components/video-views"
// import PaymentLookupForm from 'common/js/forms/payment-lookup-form'

const listGroupClass = { className: 'list-group' }

export default class UsersShowInfoPage extends Component {
  constructor(props) {
    super(props)

    this.state = { receiptUrl: false, relations: [], resetting: false, overrideEmailAddress: '', sendingCoronaEmail: false }
  }

  get hash() {
    return ((window.location || {}).hash || '')
  }

  get scrollCount() {
    return this._scrollCount || 0
  }

  set scrollCount(value) {
    this._scrollCount = Number(value || 0)
  }

  scrollToSponsorPhoto = () => this.scrollToElement("#sponsor_photo")

  scrollToLocationHash = (hash) => {
    clearTimeout(this.locationScroller)

    this.scrollCount = this.scrollCount + 1
    if(!this.scrolled && (this.hash === hash)) {
      if(document.querySelector(hash)){
        this.scrolled = true
        this.scrollCount = 0
        this.locationScroller = setTimeout(() => this.scrollToElement(hash), 100)
      } else {
        if(this.scrollCount < 1800) this.locationScroller = setTimeout(() => this.scrollToLocationHash(hash), 100)
      }
    }
  }

  async scrollToElement(hash) {
    document.querySelector(hash).scrollIntoView({ block: 'start', behavior: 'smooth' });
    // await new Promise(r => setTimeout(r, 100))
    // window.scrollBy(0, -100)
  }

  afterFetch = (args) => {
    clearTimeout(this.locationScroller)
    if(this.hash) this.locationScroller = setTimeout(() => this.scrollToLocationHash(this.hash), 1000)

    return this.props.afterFetch(args)
  }
  afterMeetingFetch = () => this.props.afterMeetingFetch()
  copyDeposit = () => this.props.copyDeposit()
  copyInfoVideo = () => this.props.copyInfoVideo()
  copyDusId = () => this.props.copyDusId()
  viewStatement = () => this.props.viewStatement()
  viewChecklist = () => this.props.viewChecklist()
  viewOverPayment = () => this.props.viewOverPayment()
  viewPostcardLabel = () => this.props.viewAuthPage('postcard')
  viewAuthPage = (...args) => this.props.viewAuthPage(...args)

  setRelations = (relations) => this._unmounted || this.setState({ relations })

  onPaymentSuccess = (id) => {
    console.log(`Payment Successful: ${id}`)
    this._unmounted || this.setState({
      receiptUrl: `https://www.downundersports.com/payments/${id}`
    })
    return true
  }

  newPayment = () => this.setState({receiptUrl: false, showCheckEntry: false, showLookup: false, showPmt: true})
  newLookup = () => this.setState({receiptUrl: false, showCheckEntry: false, showLookup: true, showPmt: false})
  newCheckEntry = () => this.setState({receiptUrl: false, showCheckEntry: true, showLookup: false, showPmt: false})

  overrideEmailAddressChange = (ev) => this.setState({ overrideEmailAddress: ev.currentTarget.value || '' })
  sendCoronaEmail = (ev, location, confirmation_message) => {
    try {
      ev.preventDefault()
      ev.stopPropagation()
    } catch(_) {}

    if(
      this.state.overrideEmailAddress
      && !/^([^@;]+@[^@;]+\.[^@;.]+)([;]\s*[^@;]+@[^@;]+\.[^@;.]+)*$/.test(this.state.overrideEmailAddress)
    ) {
      window.alert('Invalid Email(s) Given. Email override must be separated by a semi-colon (;) for multiple emails')
      return false
    }

    if(
      window.confirm(`Are you sure you want to send ${
        confirmation_message
      } to ${
        this.state.overrideEmailAddress
        || 'this user and their parents/guardians (if minor)'
      }?`)
    ) {
      this.setState({ sendingCoronaEmail: true }, async () => {
        const options = {
          method: 'POST',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
        }

        if(this.state.overrideEmailAddress) options.body = JSON.stringify({ email: this.state.overrideEmailAddress })

        const result = await fetch(`/admin/users/${this.props.id}/${location}`, options)

        await result.json()

        this.setState({ sendingCoronaEmail: false })
      })
    }
  }

  sendOnTheFence = (ev) => this.sendCoronaEmail(ev, 'on_the_fence', '"On the Fence"')
  // sendReminderCancel = (ev) =>
  //   this.sendCoronaEmail(ev, 'reminder_cancel', 'Cancelation Options (Reminder)')
  // sendSelectedCancel = (ev) =>
  //   this.sendCoronaEmail(ev, 'selected_cancel', 'Cancelation Options (Preselected)')
  // sendUnselectedCancel = (ev) =>
  //   this.sendCoronaEmail(ev, 'unselected_cancel', 'Cancelation Options (Unselected)')
  sendCancelInfo = (ev) =>
    this.sendCoronaEmail(ev, 'cancel_info', 'Cancel Information (Account Options)')

  onAvatarAttached = (avatar) =>
    this.afterFetch({
      skipTime: true,
      user: {
        ...this.props.user,
        avatar,
        avatar_attached: true
      }
    })

  componentWillUnmount() {
    this._unmounted = true
    clearTimeout(this.locationScroller)
  }

  get refundAmountView() {
    const id = this.props.id,
          { host, protocol = "https:" } = window.location,
          base_host = host.replace(/^(authorize|admin|www)\./, '').replace("3000", "3100")
    return `${protocol}//authorize.${base_host}/admin/users/${id}/refund_view`
  }

  render() {
    const {
      user: {
        avatar_attached = false,
        avatar,
        can_send_fence,
        can_send_corona,
        dus_id,
        category,
        traveler = false,
        team,
        staff_page = false,
        final_packet_base = '',
        is_fully_canceled = false
      },
      id,
      lastFetch = 0
    } = this.props || {},
    {
      receiptUrl,
      relations = [],
      overrideEmailAddress = '',
      sendingCoronaEmail = false
    } = this.state || {}

    return (
      <section key={id} className='user-info-wrapper'>
        <header>
          <nav className="nav nav-tabs">
            <input type="checkbox" id="user-info-nav-trigger" className="nav-trigger" />
            <label htmlFor="user-info-nav-trigger" className="nav-item nav-link d-md-none">
              <span><span></span></span>
              User and Relations
            </label>
            <div className='nav-item nav-link active'>
              Current User
            </div>
            {
              relations && relations.map((rel, i) => (
                <Link
                  key={rel.related_user_id}
                  to={`/admin/users/${rel.related_user_id}`}
                  className={`nav-item nav-link ${rel.traveling && 'border-success text-success'} ${rel.canceled && 'border-danger text-danger'}`}
                >
                  {rel.first} {rel.last} - {rel.relationship} ({rel.category})
                </Link>
              ))
            }
            <div className="flex-fill justify-content-end d-none d-md-flex">
              <button
                type="button"
                className="nav-item nav-link bg-info text-white"
                onClick={this.scrollToSponsorPhoto}
              >
                Sponsor Photo
              </button>
            </div>
          </nav>
        </header>
        <div  className="row form-group user-info">
          <style>
            {'html { font-size: 13px }'}
          </style>
          <div className="col-xl order-xl-last">
            { !!traveler && (
                <CardSection
                  className='mb-3 bg-warning'
                  label='2021 Transfer Info'
                  contentProps={listGroupClass}
                >
                  <div className="list-group-item">
                    <TransferExpectationForm
                      key={`${id}.${dus_id}`}
                      id={id}
                    />
                  </div>
                  {
                    !!can_send_fence && !!is_fully_canceled && (
                      <div className="list-group-item">
                        <a href={this.refundAmountView} className="btn btn-block btn-secondary form-group">
                          Open Refund Summary Form
                        </a>
                      </div>
                    )
                  }
                  {
                    !!can_send_corona && (
                      <DisplayOrLoading display={!sendingCoronaEmail}>
                        <div className="list-group-item">
                          {
                            !!can_send_fence && (
                              <button className="btn btn-block btn-success form-group" onClick={this.sendOnTheFence}>
                                Send &ldquo;On The Fence&rdquo; Email
                              </button>
                            )
                          }
                          {/*
                            <button className="btn btn-block btn-warning form-group" onClick={this.sendUnselectedCancel}>
                              Send &ldquo;Unselected&rdquo; Cancel Email
                            </button>
                            <button className="btn btn-block btn-warning form-group" onClick={this.sendSelectedCancel}>
                              Send &ldquo;Preselected&rdquo; Cancel Email
                            </button>
                            <button className="btn btn-block btn-warning form-group" onClick={this.sendReminderCancel}>
                              Send &ldquo;Reminder&rdquo; Cancel Email
                            </button>
                          */}
                          <button className="btn btn-block btn-warning form-group" onClick={this.sendCancelInfo}>
                            Send Cancel Information Email
                          </button>
                          <div className="row">
                            <div className="col">
                              <label htmlFor="on-the-fence">
                                Override Email &ldquo;To&rdquo; (optional)
                              </label>
                              <input
                                type="text"
                                id="on-the-fence"
                                className="form-control"
                                value={overrideEmailAddress}
                                onChange={this.overrideEmailAddressChange}
                              />
                            </div>
                          </div>
                        </div>
                      </DisplayOrLoading>
                    )
                  }
                </CardSection>
              )
            }
            {
              receiptUrl ? (
                <div className="alert alert-success form-group" role="alert">
                  <div className='row'>
                    <div className="col-sm">
                      <Link className='btn btn-secondary btn-block' to={receiptUrl} target='_view_receipt'>View Receipt</Link>
                    </div>
                    <div className="col-sm">
                      <button onClick={this.newPayment} className="btn btn-block btn-warning clickable">
                        Show Payment Form
                      </button>
                    </div>
                  </div>
                </div>
              ) : (
                <CardSection
                  className='mb-3'
                  label='Take A Payment'
                  contentProps={listGroupClass}
                >
                  {
                    /*this.state.showLookup ? (
                      <PaymentLookupForm
                        id={id}
                        key={`${id}.${dus_id}`}
                        teamSelect={!traveler && (/^(ath|coach|staff)/i).test(category)}
                        sportId={(team || {}).sport_id}
                        stateId={(team || {}).state_id}
                        url={`/admin/users/${id}/payments/lookup`}
                        onSuccess={this.onPaymentSuccess}
                        breakPoint='col-12'
                        {...this.props}
                      />
                    ) : (
                      <div>
                        <button className='mt-3 btn-block btn-primary clickable' onClick={this.newLookup}>
                          Show Payment Form
                        </button>
                      </div>
                    ) */
                  }
                  {
                    this.state.showCheckEntry ? (
                      <CheckPaymentForm
                        id={id}
                        key={`${id}.${dus_id}`}
                        teamSelect={!traveler && (/^(ath|coach|staff)/i).test(category)}
                        sportId={(team || {}).sport_id}
                        stateId={(team || {}).state_id}
                        url={`/admin/users/${id}/payments/ach`}
                        onSuccess={this.onPaymentSuccess}
                        breakPoint='col-12'
                        {...this.props}
                      />
                    ) : (
                      <div>
                        <button className='mt-3 btn-block btn-primary clickable' onClick={this.newCheckEntry}>
                          Show Check/ACH Entry Form
                        </button>
                      </div>
                    )
                  }
                  {
                    this.state.showPmt ? (
                      <PaymentForm
                        id={id}
                        key={`${id}.${dus_id}`}
                        teamSelect={!traveler && (/^(ath|coach|staff)/i).test(category)}
                        sportId={(team || {}).sport_id}
                        stateId={(team || {}).state_id}
                        url={`/admin/users/${id}/payments`}
                        onSuccess={this.onPaymentSuccess}
                        captcha='dus-staff'
                        breakPoint='col-12'
                        {...this.props}
                      />
                    ) : (
                      <div>
                        <button className='mt-3 btn-block btn-primary clickable' onClick={this.newPayment}>
                          Show Payment Form
                        </button>
                        {
                          traveler ? (
                            <>
                              <button key='statement' className='mt-3 btn-block btn-primary clickable' onClick={this.viewStatement}>
                                View Statement
                              </button>
                              <button key='checklist' className='mt-3 btn-block btn-primary clickable' onClick={this.viewChecklist}>
                                View Checklist
                              </button>
                              <button key='postcard' className='mt-3 btn-block btn-primary clickable' onClick={this.viewPostcardLabel}>
                                Print Postcard Label
                              </button>
                              <button key='overpayment' className='mt-3 btn-block btn-primary clickable' onClick={this.viewOverPayment}>
                                Request Over Payment
                              </button>
                            </>
                          ) : (
                            <>
                              <button
                                className='mt-3 btn-block btn-primary clickable copyable'
                                onClick={this.copyInfoVideo}
                              >
                                Info Video Link
                              </button>
                            </>
                          )
                        }
                        <button
                          className='mt-3 btn-block btn-primary clickable copyable'
                          onClick={this.copyDeposit}
                        >
                          {traveler ? 'Payment' : 'Deposit'} Page Link
                        </button>
                      </div>
                    )
                  }
                </CardSection>
              )
            }
            { !!traveler && <Printing link={final_packet_base} /> }
            { !!traveler && <Requests id={id} key={`requests-${id}`} lastFetch={lastFetch} /> }
            <Notes id={id} key={`notes-${id}`} lastFetch={lastFetch} />
            <ContactHistories id={id} key={`history-${id}`} lastFetch={lastFetch} />
            <ContactAttempts id={id} key={`attempts-${id}`} lastFetch={lastFetch} />
            <Mailings id={id} key={`mailings-${id}`} lastFetch={lastFetch} />
            <Avatar
              key={`avatar-${id}`}
              id={id}
              avatar_attached={avatar_attached}
              avatar={avatar}
              lastFetch={lastFetch}
              onAttach={this.onAvatarAttached}
            />
          </div>
          <div className="col-lg">
            <UserInfo
              key={id || 'new'}
              id={id}
              afterFetch={this.afterFetch}
            />
            <CardSection
              className='mb-3'
              label='Ambassadors'
              contentProps={listGroupClass}
            >
              <AmbassadorInfo key={`ambassadors.${dus_id}`} id={id} />
            </CardSection>
            <CardSection
              className='mb-3'
              label='Incentive Deadlines'
              contentProps={listGroupClass}
            >
              <IncentiveDeadlinesUploadForm key={`incentives.${dus_id}`} dus_id={dus_id} />
            </CardSection>
            <CardSection
              className='mb-3'
              label='Fundraising Packet'
              contentProps={listGroupClass}
            >
              <FundraisingPacketUploadForm key={`fundraising.${dus_id}`} dus_id={dus_id} />
            </CardSection>
            <CardSection
              className='mb-3'
              label='Passport'
              contentProps={listGroupClass}
            >
              <div className="list-group-item">
                <PassportForm key={`passport.${dus_id}`} dusId={dus_id} dividerClassName="col-xl" />
              </div>
            </CardSection>
            <CardSection
              className='mb-3'
              label='Legal Form'
              contentProps={listGroupClass}
            >
              <LegalUploadForm key={`legal.${dus_id}`} dus_id={dus_id} />
            </CardSection>
            <CardSection
              className='mb-3'
              label='Assignment of Benefits'
              contentProps={listGroupClass}
            >
              <BenefitsUploadForm key={`legal.${dus_id}`} dus_id={dus_id} />
            </CardSection>
            <CardSection
              className='mb-3'
              label='Proof(s) of Insurance'
              contentProps={listGroupClass}
            >
              <InsuranceUploadForm key={`insurance.${dus_id}`} dus_id={dus_id} />
            </CardSection>
            <CardSection
              className='mb-3'
              label='Proof(s) of Own Flights'
              contentProps={listGroupClass}
            >
              <FlightsUploadForm key={`flights.${dus_id}`} dus_id={dus_id} />
            </CardSection>
            {
              !staff_page && (
                <>
                  <CardSection
                    className='mb-3'
                    label='Meetings'
                    contentProps={listGroupClass}
                  >
                    <MeetingRegistrations
                      id={id}
                      afterFetch={this.afterMeetingFetch}
                    />
                  </CardSection>
                  <CardSection
                    className='mb-3'
                    label='Videos'
                    contentProps={listGroupClass}
                  >
                    <VideoViews
                      id={id}
                      afterFetch={this.afterMeetingFetch}
                    />
                  </CardSection>
                </>
              )
            }
          </div>
          <div className="col-lg">
            <div className="d-lg-none">
              <hr/>
              <hr/>
            </div>
            <UserRelations id={id} setRelations={this.setRelations}/>
          </div>
        </div>
      </section>

    );
  }
}
