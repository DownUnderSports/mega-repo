import React, { Component } from 'react';
import { format } from 'date-fns'
import pixelTracker from 'common/js/helpers/pixel-tracker'

import MeetingCountdown from 'common/js/components/meeting/countdown';
import { Meeting } from 'common/js/contexts/meeting'

const dateFormat = 'dddd, MMMM Do'

class MeetingsShowPage extends Component {
  constructor(props) {
    super(props)
    const time = new Date().getTime()
    this.state = { time, date: format(time, dateFormat) }
  }
  async fetchMeeting(props) {
    try {
      const meetingId = this.meetingIdFromProps(props)

      if(!meetingId) throw new Error('No Meeting ID')

      return await props.meetingActions.getMeetingTime(meetingId)
    } catch (e) {
      console.error(e)
    }
  }
  /**
   * Fetch Meeting On Mount
   *
   * @private
   */
  componentDidMount = async () => {
    pixelTracker('track', 'PageView')
    this.setTime(await this.fetchMeeting(this.props))
  }

  async componentDidUpdate(props){
    const oldId = this.meetingIdFromProps(props)
    const newId = this.meetingIdFromProps(this.props)

    if(oldId !== newId) this.setTime(await this.fetchMeeting(this.props))
  }

  meetingIdFromProps(props) {
    return ((props.match || {}).params || {}).meetingId
  }

  setTime = (time) => {
    time = new Date( time || null ).getTime()
    this.setState({ time, date: format(time, dateFormat) })
  }



  render() {
    return (
      <div className="row my-5">
        <div className="col-12 form-group text-center">
          <h3>
            The Meeting on {this.state.date} Begins In:
          </h3>
        </div>
        <div className='col-12'>
          <MeetingCountdown
            time={this.state.time || null}
            key={this.state.time || 'unknown'}
          />
        </div>
      </div>
    )
  }
}

export default Meeting.Decorator(MeetingsShowPage)
