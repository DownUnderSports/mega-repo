import React, { Component } from 'react';
import UserCalls from 'components/user-calls'

export default class UsersShowCallsPage extends Component {
  afterFetch = (args) => this.props.afterFetch(args)
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
      this.setState({sponsorPhotoLoading: false, sponsorPhotoErrors: [err.message, ...((await err.response.json()).errors || [])]})
    } catch(_) {
      this.setState({sponsorPhotoLoading: false, sponsorPhotoErrors: [err.toString()]})
    }
  }

  newPayment = () => this.setState({receiptUrl: false, showCheckEntry: false, showLookup: false, showPmt: true})
  newLookup = () => this.setState({receiptUrl: false, showCheckEntry: false, showLookup: true, showPmt: false})
  newCheckEntry = () => this.setState({receiptUrl: false, showCheckEntry: true, showLookup: false, showPmt: false})

  get middleName() {
    return this.props.user.middle ? ` ${this.props.user.middle}` : ''
  }

  get suffixName() {
    return this.props.user.suffix ? ` ${this.props.user.suffix}` : ''
  }

  get printName() {
    if(!this.props.user) return ''
    return `${
      this.props.user.print_first_names || `${this.props.user.first}${this.middleName}`
    } ${
      this.props.user.print_other_names || `${this.props.user.last}${this.suffixName}`
    }`
  }

  get fullName() {
    if(!this.props.user) return ''
    return `${
      this.props.user.title || ''
    } ${
      this.props.user.first || ''
    } ${
      this.props.user.middle || ''
    } ${
      this.props.user.last || ''
    } ${
      this.props.user.suffix || ''
    }`
  }

  get travelPrep() {
    const {
      travel_preparation_attributes = {}
    } = this.props.user || {}

    return travel_preparation_attributes || {}
  }

  get category() {
    if(!this.props.user) return ''
    return this.props.user.category
  }

  componentWillUnmount() {
    this._unmounted = true
  }

  render() {
    const { id } = this.props || {}

    return (
      <section key={id} className='user-calls-wrapper'>
        <header>
          <h3>Traveler Call Followup</h3>
          <h4>{ this.fullName }</h4>
        </header>
        <UserCalls
          key={id || 'new'}
          id={id}
          fullName={this.fullName}
          printName={this.printName}
          travelPrep={this.travelPrep}
          category={this.category}
          afterFetch={this.afterFetch}
        />
      </section>

    );
  }
}
