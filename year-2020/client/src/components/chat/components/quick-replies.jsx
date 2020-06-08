import React, { Component } from 'react'
// import { CurrentUser } from 'common/js/contexts/current-user'

export default class QuickReplies extends Component {
  // static contextType = CurrentUser.Context

  get name() {
    return String(this.props.name || '')
  }

  get firstName() {
    return this.name.split(' ')[0]
  }

  // async componentDidMount() {
  //   if(!this.context.currentUserState.loaded) await this.context.currentUserActions.getCurrentUser()
  // }

  setMessage = (msg) => msg && this.props.setMessage && this.props.setMessage(msg)

  cost = () =>
    this.setMessage("Our Australia Tournament Package costs $4699 per person. It includes international airfare, tour guides, hotel accommodations, two meals per day, tournament fees, sight-seeing, a koala photo, and more. We provide each athlete with fundraising tools to help cover the cost.")

  welcome = () =>{
    const firstName = this.firstName
    let greeting = "G'Day"
    if(firstName) greeting = `G'Day ${firstName}`
    this.setMessage(`${greeting}! You've reached Down Under Sports, how can I help you today?`)
  }

  dusId = () =>
    this.setMessage("What is your DUS ID?")

  getEmail = () =>
    this.setMessage("What is your email address?")

  getPhone = () =>
    this.setMessage("What is your phone number?")

  invited = () =>
    this.setMessage("Have you received an invitation to compete?")

  render() {
    return (
      <>
        <h3 className="text-center" key="header">
          Quick Replies
        </h3>
        <div key="buttons" className="quick-replies">
          <button type="button" className="btn btn-secondary" onClick={this.welcome}>Welcome!</button>
          <button type="button" className="btn btn-secondary" onClick={this.cost}>Base Cost</button>
          <button type="button" className="btn btn-secondary" onClick={this.dusId}>DUS ID</button>
          <button type="button" className="btn btn-secondary" onClick={this.invited}>Invited?</button>
          <button type="button" className="btn btn-secondary" onClick={this.getEmail}>Email?</button>
          <button type="button" className="btn btn-secondary" onClick={this.getPhone}>Phone?</button>
        </div>
      </>
    )
  }
}
