import React, { Component } from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import dateFns from 'date-fns'


export const url = '/admin/users/:id/travel_preparation.json'
// const requiredKeys = [
//   'calls',
//   'items_received'
// ]

export default class UserCalls extends Component {
  state = { reloading: false }

  get travelPrep() {
    return this.props.travelPrep || {}
  }

  get travelPrepCalls() {
    return this.travelPrep.calls || {}
  }

  get travelPrepEmails() {
    return this.travelPrep.emails || {}
  }

  get printName() {
    return this.props.printName
  }

  get fullName() {
    return this.props.fullName
  }

  get category() {
    return this.props.category
  }

  async componentDidMount(){
    if(this.props.id) await this.reload()
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.reload()
  }

  componentWillUnmount() {
    this._unmounted = true
    this.abortFetch()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  reload = async () => {
    if(this._unmounted) return false
    this.setState({ reloading: true })
    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('UserInfo: No User ID')
      if(!this.props.afterFetch) throw new Error('No Callback Defined: "afterFetch"')

      this._fetchable = fetch(url.replace(/:id\/[a-z_]+/, this.props.id), {timeout: 5000})
      const result = await this._fetchable,
            user = await result.json()

      this.props.afterFetch({ user })
      this.setState({reloading: false})
    } catch(e) {
      console.error(e)
      this._unmounted || this.setState({
        reloading: false,
      })
    }
  }

  markTravelPrep = async (ev, category, message, prepType = false) => {
    try {
      ev.preventDefault()
      ev.stopPropagation()
      this.setState({reloading: true})

      const value = prepType ? document.getElementById(`${category.replace(/^(call|email)ed_|_type$/g, '')}_input`).value : ''

      if(prepType && !value) throw new Error("No Selection Made")

      const confirmed = window.confirm(
        `Are you sure you want to mark ${
          message
          .replace(/FULL_NAME_WITH_CATEGORY/g, `${this.fullName} (${this.category})`)
          .replace(/STATUS/g, value.split("_").join(" a "))
        }?`
      )

      if(confirmed) {

        await fetch(url.replace(':id', this.props.id), {
          method: 'PATCH',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify({ category, value })
        });

        await this.reload()
      } else {
        throw new Error("Change was not confirmed")
      }
    } catch (err) {
      this._unmounted || this.setState({reloading: false})
      try {
        const resp = await err.response.json()
        console.log(resp)
        alert(resp.errors[0])
      } catch(e) {
        console.error(err)
        alert(err.message)
      }
    }
  }

  dayAfterCall = ev => this.markTravelPrep(ev, 'called_day_after_type', 'FULL_NAME_WITH_CATEGORY was STATUS the day after signup', true)
  weekOneCall = ev => this.markTravelPrep(ev, 'called_week_one_type', 'FULL_NAME_WITH_CATEGORY was STATUS 1 week after signup', true)
  weekTwoCall = ev => this.markTravelPrep(ev, 'called_week_two_type', 'FULL_NAME_WITH_CATEGORY was STATUS 2 weeks after signup', true)
  weekThreeCall = ev => this.markTravelPrep(ev, 'called_week_three_type', 'FULL_NAME_WITH_CATEGORY was STATUS 3 weeks after signup', true)
  weekFourCall = ev => this.markTravelPrep(ev, 'called_week_four_type', 'FULL_NAME_WITH_CATEGORY was STATUS 4 weeks after signup', true)
  departureCall = ev => this.markTravelPrep(ev, 'called_departure_type', 'FULL_NAME_WITH_CATEGORY was STATUS for their departure', true)

  firstDecemberCall = ev => this.markTravelPrep(ev, 'called_first_december_type', 'FULL_NAME_WITH_CATEGORY was STATUS in December', true)
  secondDecemberCall = ev => this.markTravelPrep(ev, 'called_second_december_type', 'FULL_NAME_WITH_CATEGORY was STATUS in December', true)
  firstJanuaryCall = ev => this.markTravelPrep(ev, 'called_first_january_type', 'FULL_NAME_WITH_CATEGORY was STATUS in January', true)
  secondJanuaryCall = ev => this.markTravelPrep(ev, 'called_second_january_type', 'FULL_NAME_WITH_CATEGORY was STATUS in January', true)
  firstFebruaryCall = ev => this.markTravelPrep(ev, 'called_first_february_type', 'FULL_NAME_WITH_CATEGORY was STATUS in February', true)
  secondFebruaryCall = ev => this.markTravelPrep(ev, 'called_second_february_type', 'FULL_NAME_WITH_CATEGORY was STATUS in February', true)
  firstMarchCall = ev => this.markTravelPrep(ev, 'called_first_march_type', 'FULL_NAME_WITH_CATEGORY was STATUS in March', true)
  secondMarchCall = ev => this.markTravelPrep(ev, 'called_second_march_type', 'FULL_NAME_WITH_CATEGORY was STATUS in March', true)
  firstAprilCall = ev => this.markTravelPrep(ev, 'called_first_april_type', 'FULL_NAME_WITH_CATEGORY was STATUS in April', true)
  secondAprilCall = ev => this.markTravelPrep(ev, 'called_second_april_type', 'FULL_NAME_WITH_CATEGORY was STATUS in April', true)
  firstMayCall = ev => this.markTravelPrep(ev, 'called_first_may_type', 'FULL_NAME_WITH_CATEGORY was STATUS in May', true)
  secondMayCall = ev => this.markTravelPrep(ev, 'called_second_may_type', 'FULL_NAME_WITH_CATEGORY was STATUS in May', true)

  dayAfterVideoEmail = ev => this.markTravelPrep(ev, 'emailed_day_after_video_type', 'FULL_NAME_WITH_CATEGORY "day after" videos are/were STATUS', true)
  fundraisingVideoEmail = ev => this.markTravelPrep(ev, 'emailed_fundraising_video_type', 'FULL_NAME_WITH_CATEGORY week 1 "fundraising" videos are/were STATUS', true)
  tshirtVideoEmail = ev => this.markTravelPrep(ev, 'emailed_tshirt_video_type', 'FULL_NAME_WITH_CATEGORY week 2 "t-shirt" videos are/were STATUS', true)
  reviewVideoEmail = ev => this.markTravelPrep(ev, 'emailed_review_video_type', 'FULL_NAME_WITH_CATEGORY week 3 "review" videos are/were STATUS', true)
  passportVideoEmail = ev => this.markTravelPrep(ev, 'emailed_passport_video_type', 'FULL_NAME_WITH_CATEGORY week 4 "passport" videos are/were STATUS', true)
  gbrVideoEmail = ev => this.markTravelPrep(ev, 'emailed_gbr_video_type', 'FULL_NAME_WITH_CATEGORY "great barrier reef" videos are/were STATUS', true)

  callOrEmailField = (category, section) => {
    const object = this[`travelPrep${section}s`],
          label = category.split("_").map((v, i) => v.capitalize()).join(" "),
          func = this[label.replace(/\s+/g, "").replace(/^[A-Z]/, category[0]) + section],
          date = object[`${category}_date`] && dateFns.format(object[`${category}_date`], 'MMMM D, YYYY'),
          result = date && object[`${category}_type`],
          staff = date && object[`${category}_user`]

    return (
      <div key={category} className="list-group-item">
        <strong>{label} {section}:</strong>
        {
          date
          ? <div>{date} - <strong>{result}</strong> {!!staff && `(${staff})`}</div>
          : (
            <div className="row">
              <div className="col">
                { this[`select${section}Field`](category) }
              </div>
              <div className="col">
                <button type="button" className='btn btn-primary btn-block' onClick={func}>
                  Mark {section}
                </button>
              </div>
            </div>
          )
        }
      </div>
    )
  }


  callField = (category) => {
    const calls = this.travelPrepCalls,
          label = category.split("_").map((v, i) => v.capitalize()).join(" "),
          func = this[label.replace(/\s+/g, "").replace(/^[A-Z]/, category[0]) + 'Call'],
          date = calls[`${category}_date`] && dateFns.format(calls[`${category}_date`], 'MMMM D, YYYY'),
          result = date && calls[`${category}_type`],
          staff = date && calls[`${category}_user`]

    return (
      <div key={category} className="list-group-item">
        <strong>{label} Call:</strong>
        {
          date
          ? <div>{date} - <strong>{result}</strong> {!!staff && `(${staff})`}</div>
          : (
            <div className="row">
              <div className="col">
                { this.selectField(category) }
              </div>
              <div className="col">
                <button type="button" className='btn btn-primary btn-block' onClick={func}>
                  Mark Call
                </button>
              </div>
            </div>
          )
        }
      </div>
    )
  }

  selectCallField = (id) =>
    <select className="form-control" name={id} id={`${id}_input`}>
      <option value="">-- SELECT --</option>
      <option value="Left a Message">Left Message</option>
      <option value="Called">Called</option>
      <option value="Not Applicable">N/A</option>
    </select>

  selectEmailField = (id) =>
    <select className="form-control" name={id} id={`${id}_input`}>
      <option value="">-- SELECT --</option>
      <option value="Sent">Sent</option>
      <option value="Not Applicable">N/A</option>
    </select>

  selectField = (id) =>
    <select className="form-control" name={id} id={`${id}_input`}>
      <option value="">-- SELECT --</option>
      <option value="Left a Message">Left Message</option>
      <option value="Called">Called</option>
      <option value="Not Applicable">N/A</option>
    </select>

  emailField = (category) =>
    this.callOrEmailField(category, 'Email')

  render() {
    return (
      <DisplayOrLoading
        display={!this.state.reloading}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        <div className="row">
          <div className="col-lg-6">
            <section className="card text-default mb-3">
              <header className="text-center card-header ">
                <h3>After Join Calls</h3>
              </header>
              <div className="list-group">
                { this.callField('day_after') }
                { this.callField('week_one') }
                { this.callField('week_two') }
                { this.callField('week_three') }
                { this.callField('week_four') }
              </div>
            </section>
          </div>
          <div className="col-lg-6">
            <section className="card text-default mb-3">
              <header className="text-center card-header ">
                <h3>After Join Emails</h3>
              </header>
              <div className="list-group">
                { this.emailField('day_after_video') }
                { this.emailField('fundraising_video') }
                { this.emailField('tshirt_video') }
                { this.emailField('review_video') }
                { this.emailField('passport_video') }
              </div>
            </section>
          </div>
          <div className="col-lg-6">
            <section className="card text-default mb-3">
              <header className="text-center card-header ">
                <h3>Travel Followup</h3>
              </header>
              <div className="list-group">
                { this.emailField('gbr_video') }
                { this.callField('departure') }
              </div>
            </section>
          </div>
          <div className="col-lg-6">
            <section className="card text-default mb-3">
              <header className="text-center card-header ">
                <h3>Monthly Calls</h3>
              </header>
              <div className="list-group">
                { this.callField('first_december') }
                { this.callField('second_december') }
                { this.callField('first_january') }
                { this.callField('second_january') }
                { this.callField('first_february') }
                { this.callField('second_february') }
                { this.callField('first_march') }
                { this.callField('second_march') }
                { this.callField('first_april') }
                { this.callField('second_april') }
                { this.callField('first_may') }
                { this.callField('second_may') }
              </div>
            </section>
          </div>
        </div>
      </DisplayOrLoading>
    );
  }
}
