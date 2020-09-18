import React, { Component } from 'react';
import { CardSection, DisplayOrLoading, Link } from 'react-component-templates/components';
import UserInfo from 'components/user-info'
import UserRelations from 'components/user-relations'
import AmbassadorInfo from 'components/ambassador-info'
import MeetingRegistrations from 'components/meeting-registrations'
import VideoViews from 'components/video-views'
import ContactAttempts from 'components/user-contact-attempts'
import ContactHistories from 'components/user-contact-history'
import Notes from 'components/user-notes'
import Requests from 'components/requests'
import Mailings from 'components/user-mailings'
import Printing from 'components/user-printing'
import PaymentForm from 'common/js/forms/payment-form'
// import PaymentLookupForm from 'common/js/forms/payment-lookup-form'
import TransferExpectationForm from 'forms/transfer-expectation-form'
import CheckPaymentForm from 'forms/check-payment-form'
import PassportForm from 'forms/passport-form'
import BenefitsUploadForm from 'forms/benefits-upload-form'
import LegalUploadForm from 'forms/legal-upload-form'
import InsuranceUploadForm from 'forms/insurance-upload-form'
import FlightsUploadForm from 'forms/flights-upload-form'
import IncentiveDeadlinesUploadForm from 'forms/incentive-deadlines-upload-form'
import FundraisingPacketUploadForm from 'forms/fundraising-packet-upload-form'
import ActiveStorageProvider from 'react-activestorage-provider'
import AuthStatus from 'common/js/helpers/auth-status'

export default class UsersShowInfoPage extends Component {
  constructor(props) {
    super(props)

    this.state = { receiptUrl: false, relations: [], sponsorPhoto: false, sponsorPhotoErrors: [], sponsorPhotoLoading: false, resetting: false, overrideEmailAddress: '', sendingCoronaEmail: false }
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

  onSponsorPhotoError = async (err) => {
    if(this._unmounted) return false
    try {
      this.setState({sponsorPhotoLoading: false, sponsorPhotoErrors: [err.request, ...((await err.response.json()).errors || [])]})
    } catch(_) {
      this.setState({sponsorPhotoLoading: false, sponsorPhotoErrors: [err.toString()]})
    }
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
                  contentProps={{className: 'list-group'}}
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
                  contentProps={{className: 'list-group'}}
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
            <CardSection
              id="sponsor_photo"
              className='mb-3 border border-info bg-info text-white scroll-margin'
              label='Sponsor Photo'
              contentProps={{className: 'list-group'}}
            >
              {
                avatar_attached && (
                  <div className="list-group-item text-center">
                    <DisplayOrLoading display={!this.state.sponsorPhotoLoading}>
                      <img src={avatar} className='img-fluid rounded' alt="avatar"/>
                    </DisplayOrLoading>
                  </div>
                )
              }
              <div className="list-group-item">
                <DisplayOrLoading
                  display={!this.state.resetting}
                >
                  <ActiveStorageProvider
                    endpoint={{
                      path: `/admin/users/${id}/avatar`,
                      model: 'User',
                      attribute: 'avatar',
                      method: 'PUT'
                    }}
                    onError={this.onSponsorPhotoError}
                    headers={{
                      ...AuthStatus.headerHash,
                      'X-CSRF-Token': '',
                      'Content-Type': 'application/json;charset=UTF-8',
                    }}
                    onSubmit={
                      e => this.setState({
                        sponsorPhoto: false,
                        sponsorPhotoErrors: [],
                        sponsorPhotoLoading: false,
                      }, () => this.afterFetch({skipTime: true, user: {...this.props.user, avatar: e.avatar, avatar_attached: true}}))
                    }
                    render={({ handleUpload, uploads, ready }) => {
                      return (
                        <div className="row">
                          <div className="col form-group">
                            <div className="input-group">
                              <div className="input-group-prepend">
                                <i className="input-group-text material-icons">image</i>
                              </div>
                              <div className="custom-file">
                                <input
                                  type="file"
                                  id="sponsor-photo-input"
                                  name="sponsor-photo-input"
                                  className="form-control-file"
                                  placeholder='select sponsor photo'
                                  onChange={(e) => this.setState({sponsorPhoto: e.currentTarget.files})}
                                  disabled={!ready}
                                />
                                <label className="custom-file-label" htmlFor="sponsor-photo-input">
                                  {
                                    (
                                      this.state.sponsorPhoto && this.state.sponsorPhoto.length
                                    ) ? this.state.sponsorPhoto[0].name : 'Choose file...'
                                  }
                                </label>
                              </div>
                            </div>
                          </div>
                          <div className='col-2 form-group'>
                            <button
                              className='btn btn-block btn-primary'
                              disabled={!ready || !this.state.sponsorPhoto || !this.state.sponsorPhoto.length}
                              onClick={e => {
                                e.preventDefault()
                                e.stopPropagation()
                                this.setState({sponsorPhotoLoading: true})
                                handleUpload(this.state.sponsorPhoto).catch(this.onSponsorPhotoError)
                              }}
                            >
                              Submit
                            </button>
                          </div>
                          <div className="col-12">
                            {
                              (this.state.sponsorPhotoErrors || []).map((err, i) => (
                                <div className='row' key={i}>
                                  <div className="col-12 text-danger">
                                    <p>
                                     {err}
                                    </p>
                                  </div>
                                </div>
                              ))
                            }
                            {uploads.map(upload => {
                              switch (upload.state) {
                                case 'waiting':
                                  return <p key={upload.id}>Waiting to upload {upload.file.name}</p>
                                case 'uploading':
                                  return (
                                    <p key={upload.id}>
                                      Uploading {upload.file.name}: {upload.progress}%
                                    </p>
                                  )
                                case 'error':
                                  return (
                                    <p key={upload.id}>
                                      Error uploading {upload.file.name}: {upload.error}
                                      <button
                                        className='btn btn-block mt-3 btn-warning'
                                        onClick={() => {
                                          this.setState({sponsorPhoto: null, resetting: true}, () => {
                                            setTimeout(this.setState({resetting: false}))
                                          })
                                        }}
                                      >
                                        Reset Form
                                      </button>
                                    </p>
                                  )
                                case 'finished':
                                  return <p key={upload.id}>Finished uploading {upload.file.name}</p>
                                default:
                                  return <p key={upload.id}>An Unknown Error Occured</p>
                              }
                            })}
                          </div>
                        </div>
                      )
                    }}
                  />
                </DisplayOrLoading>
              </div>
            </CardSection>
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
              contentProps={{className: 'list-group'}}
            >
              <DisplayOrLoading
                display={!this.state.resetting}
              >
                <AmbassadorInfo key={`ambassadors.${dus_id}`} id={id} />
              </DisplayOrLoading>
            </CardSection>
            <CardSection
              className='mb-3'
              label='Incentive Deadlines'
              contentProps={{className: 'list-group'}}
            >
              <DisplayOrLoading
                display={!this.state.resetting}
              >
                <IncentiveDeadlinesUploadForm key={`incentives.${dus_id}`} dus_id={dus_id} />
              </DisplayOrLoading>
            </CardSection>
            <CardSection
              className='mb-3'
              label='Fundraising Packet'
              contentProps={{className: 'list-group'}}
            >
              <DisplayOrLoading
                display={!this.state.resetting}
              >
                <FundraisingPacketUploadForm key={`fundraising.${dus_id}`} dus_id={dus_id} />
              </DisplayOrLoading>
            </CardSection>
            <CardSection
              className='mb-3'
              label='Passport'
              contentProps={{className: 'list-group'}}
            >
              <div className="list-group-item">
                <DisplayOrLoading
                  display={!this.state.resetting}
                >
                  <PassportForm key={`passport.${dus_id}`} dusId={dus_id} dividerClassName="col-xl" />
                </DisplayOrLoading>
              </div>
            </CardSection>
            <CardSection
              className='mb-3'
              label='Legal Form'
              contentProps={{className: 'list-group'}}
            >
              <DisplayOrLoading
                display={!this.state.resetting}
              >
                <LegalUploadForm key={`legal.${dus_id}`} dus_id={dus_id} />
              </DisplayOrLoading>
            </CardSection>
            <CardSection
              className='mb-3'
              label='Assignment of Benefits'
              contentProps={{className: 'list-group'}}
            >
              <DisplayOrLoading
                display={!this.state.resetting}
              >
                <BenefitsUploadForm key={`legal.${dus_id}`} dus_id={dus_id} />
              </DisplayOrLoading>
            </CardSection>
            <CardSection
              className='mb-3'
              label='Proof(s) of Insurance'
              contentProps={{className: 'list-group'}}
            >
              <DisplayOrLoading
                display={!this.state.resetting}
              >
                <InsuranceUploadForm key={`insurance.${dus_id}`} dus_id={dus_id} />
              </DisplayOrLoading>
            </CardSection>
            <CardSection
              className='mb-3'
              label='Proof(s) of Own Flights'
              contentProps={{className: 'list-group'}}
            >
              <DisplayOrLoading
                display={!this.state.resetting}
              >
                <FlightsUploadForm key={`flights.${dus_id}`} dus_id={dus_id} />
              </DisplayOrLoading>
            </CardSection>
            {
              !staff_page && (
                <>
                  <CardSection
                    className='mb-3'
                    label='Meetings'
                    contentProps={{className: 'list-group'}}
                  >
                    <MeetingRegistrations
                      id={id}
                      afterFetch={this.afterMeetingFetch}
                    />
                  </CardSection>
                  <CardSection
                    className='mb-3'
                    label='Videos'
                    contentProps={{className: 'list-group'}}
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
