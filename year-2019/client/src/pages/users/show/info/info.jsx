import React, { Component } from 'react';
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import UserInfo from 'components/user-info'
import UserRelations from 'components/user-relations'
import MeetingRegistrations from 'components/meeting-registrations'
import VideoViews from 'components/video-views'
import ContactAttempts from 'components/user-contact-attempts'
import ContactHistories from 'components/user-contact-history'
import Notes from 'components/user-notes'
import Mailings from 'components/user-mailings'
import Printing from 'components/user-printing'
import PaymentForm from 'common/js/forms/payment-form'
// import PaymentLookupForm from 'common/js/forms/payment-lookup-form'
import CheckPaymentForm from 'forms/check-payment-form'
import PassportForm from 'forms/passport-form'
import BenefitsUploadForm from 'forms/benefits-upload-form'
import LegalUploadForm from 'forms/legal-upload-form'
import InsuranceUploadForm from 'forms/insurance-upload-form'
import { CardSection } from 'react-component-templates/components';
import ActiveStorageProvider from 'react-activestorage-provider'
import AuthStatus from 'common/js/helpers/auth-status'

export default class UsersShowInfoPage extends Component {
  constructor(props) {
    super(props)

    this.state = { receiptUrl: false, relations: [], sponsorPhoto: false, sponsorPhotoErrors: [], sponsorPhotoLoading: false, resetting: false }
  }

  afterFetch = (args) => this.props.afterFetch(args)
  afterMeetingFetch = () => this.props.afterMeetingFetch()
  copyDeposit = () => this.props.copyDeposit()
  copyDusId = () => this.props.copyDusId()
  viewStatement = () => this.props.viewStatement()
  viewOverPayment = () => this.props.viewOverPayment()
  viewPostcardLabel = () => this.props.viewAuthPage('postcard')
  viewAuthPage = (...args) => this.props.viewAuthPage(...args)

  setRelations = (relations) => this._unmounted || this.setState({ relations })

  onPaymentSuccess = (id) => {
    console.log(`Payment Successful: ${id}`)
    this._unmounted || this.setState({
      receiptUrl: `https://downundersports.com/payments/${id}`
    })
    return true
  }

  onSponsorPhotoError = async (err) => {
    if(this._unmounted) return false
    try {
      this.setState({sponsorPhotoLoading: false, sponsorPhotoErrors: [err.message, ...((await err.response.json()).errors || [])]})
    } catch(_) {
      this.setState({sponsorPhotoLoading: false, sponsorPhotoErrors: [err.toString()]})
    }
  }

  newPayment = () => this.setState({receiptUrl: false, showCheckEntry: false, showLookup: false, showPmt: true})
  newLookup = () => this.setState({receiptUrl: false, showCheckEntry: false, showLookup: true, showPmt: false})
  newCheckEntry = () => this.setState({receiptUrl: false, showCheckEntry: true, showLookup: false, showPmt: false})

  componentWillUnmount() {
    this._unmounted = true
  }

  render() {
    const {
      user: {
        avatar_attached = false,
        avatar,
        dus_id,
        category,
        traveler = false,
        team,
        staff_page = false,
        final_packet_base = ''
      },
      id,
      lastFetch = 0
    } = this.props || {},
    {
      receiptUrl,
      relations = []
    } = this.state || {}

    return (
      <section key={id} className='user-info-wrapper'>
        <header>
          <nav className="nav sports-nav nav-tabs">
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
                <Link key={i} to={`/admin/users/${rel.related_user_id}`} className={`nav-item nav-link ${rel.traveling && 'border-success text-success'} ${rel.canceled && 'border-danger text-danger'}`}>
                  {rel.first} {rel.last} - {rel.relationship} ({rel.category})
                </Link>
              ))
            }
          </nav>
        </header>
        <div className="main">
          <div  className="row form-group user-info">
            <div className="col-lg order-lg-last">
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
                                <button key='postcard' className='mt-3 btn-block btn-primary clickable' onClick={this.viewPostcardLabel}>
                                  Print Postcard Label
                                </button>
                                <button key='overpayment' className='mt-3 btn-block btn-primary clickable' onClick={this.viewOverPayment}>
                                  Request Over Payment
                                </button>
                              </>
                            ) : ''
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
              <Notes id={id} key={`notes-${lastFetch}`} />
              <ContactHistories id={id} key={`history-${lastFetch}`} />
              <ContactAttempts id={id} key={`attempts-${lastFetch}`} />
              <Mailings id={id} />
              <hr/>
              <hr/>
              <h2 className='text-center mb-3 mt-5'>Related Users</h2>
              <UserRelations id={id} setRelations={this.setRelations}/>
            </div>
            <div className="col-lg">
              <UserInfo
                id={id}
                afterFetch={this.afterFetch}
              />
              <CardSection
                className='mb-3'
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
          </div>
        </div>
      </section>

    );
  }
}
