import React, { Component } from 'react';
import format from 'date-fns/format'
import { Meeting } from 'common/js/contexts/meeting';
import { Objected } from 'react-component-templates/helpers'
import { SelectField } from 'react-component-templates/form-components';

export default class MeetingSelectField extends Component {
  static contextType = Meeting.Context

  constructor(props){
    super(props)
    this.state = {
      loaded: false,
      options: []
    }
  }

  async componentDidMount(){
    this._isMounted = true
    try {
      return await ((this.context.meetingState.loaded && (await this.context.meetingActions.checkVersion())) ? Promise.resolve() : this.context.meetingActions.getMeetings())
      .then(this.mapOptions)
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate(){
    const { loaded = false, options = [] } = this.state
    if(
      (!loaded && this.context.meetingState.loaded) ||
      (options.length !== this.context.meetingState.ids.length)
    ) {
      this.mapOptions()
    }
  }

  componentWillUnmount() {
    this._isMounted = false
  }

  mapOptions = () => {
    if(!this._isMounted) return false

    const { meetingState: { loaded = false, ids = [] }, meetingActions: {find = ((v) => v)} } = this.context;
    this.setState({
      loaded,
      options: ids.map((id) => find(id)).map((meeting) => ({
        value: meeting.id,
        label: `${meeting.category} - ${format(meeting.date, "ddd, MMM Do")} ${meeting.time}`,
        date: meeting.date,
        time: meeting.time,
        category: meeting.category,
      })).reverse()
    })
  }

  render() {
    return (
      <SelectField
        {...Objected.filterKeys(this.props, ['meetingState', 'meetingActions'])}
        options={this.state.options}
        filterOptions={{
          indexes: ['date', 'time', 'category', 'label']
        }}
      />
    )
  }
}
