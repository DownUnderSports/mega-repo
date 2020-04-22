import React, { Component } from 'react';
import MeetingForm from 'forms/meeting-registration-form'

export default class RegistrationInfo extends Component {
  constructor(props) {
    super(props)
    this.state = { showForm: !this.props.id }
  }

  openMeetingForm = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.setState({showForm: true})
  }

  render() {
    const {
      id,
      user_id,
      date,
      time,
      duration = '00:00:00',
      attended = false,
      category
    } = this.props || {}

    return this.state.showForm ? (
      <MeetingForm
        id={ id }
        userId={ user_id }
        onSuccess={ this.props.onSuccess || (() => this.setState({showForm: false})) }
        onCancel={ this.props.onCancel || (() => this.setState({showForm: false}))}
        url={ this.props.url || '' }
        registration={{...this.props}}
      />
    ) : (
      <div className="list-group-item clickable" onClick={this.openMeetingForm}>
        <div className={`row ${attended && 'text-success'}`}>
          <div className="col">
            Category: {category}
          </div>
          <div className="col">
            Date: {date}
          </div>
          <div className="col">
            Time: {time}
          </div>
          {
            attended && (
              <div className="col">
                Attended For: {duration}
              </div>
            )
          }
        </div>
      </div>
    );
  }
}
