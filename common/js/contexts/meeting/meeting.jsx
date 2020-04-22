import React, {createContext, Component} from 'react'
import { objectOf, arrayOf, func, shape, string, number, bool } from 'prop-types'
import { Spaceship }  from 'react-component-templates/helpers'
import { format } from 'date-fns'

const meetingUrl = '/api/meetings'

export const Meeting = {}

Meeting.DefaultValues = {
  ids: [],
  version: '',
  loaded: false,
  mappings: {},
  meetings: {},
}

Meeting.Context = createContext({
  meetingState: {...Meeting.DefaultValues},
  meetingActions: {
    checkVersion(){},
    getMeetings(){},
    getMeetingTime(){},
    find(){},
  }
})

Meeting.Decorator = function withMeetingContext(Component) {
  return (props) => (
    <Meeting.Context.Consumer>
      {meetingProps => <Component {...props} {...meetingProps} />}
    </Meeting.Context.Consumer>
  )
}

Meeting.meetingShape = () => shape({
  id: number.isRequired,
  date: string.isRequired,
  time: string.isRequired,
  category: string,
})

Meeting.PropTypes = {
  meetingState: shape({
    loaded: bool,
    version: string,
    ids: arrayOf(number),
    mappings: objectOf(number),
    meetings: objectOf(
      Meeting.meetingShape()
    ),
  }),
  meetingActions: shape({
    checkVersion: func,
    getMeetings: func,
    getMeetingTime: func,
    find: func,
  }).isRequired
}

const mapMeetingProps = (meeting, show = false) => {
  const array = meeting.array || [meeting.year, meeting.month, meeting.day, meeting.hour, meeting.minutes, meeting.second].map((v) => (v || 0));
  const d = new Date(Date.UTC(...array))
  return {
    id: +meeting.id,
    date: format(d, 'YYYY-MM-DD'),
    time: format(d, 'hh:mm:ss A'),
    category: meeting.category,
    value: d
  }
}

export default class ReduxMeetingProvider extends Component {
  state = { ...Meeting.DefaultValues }

  render() {
    return (
      <Meeting.Context.Provider
        value={{
          meetingState: this.state,
          meetingActions: {
            /**
             * @returns {boolean} upToDate - if meeting list is up to date
             **/
            checkVersion: async () => {
              try {
                if(!this.state.version) throw new Error('version not set')
                await fetch(`${meetingUrl}/version/${this.state.version}`)
                return true
              } catch (e) {
                this.setState({
                  version: '',
                  loaded: false,
                })
                return false
              }
            },
            getMeetingTime: async (meetingId) => {
              try {
                const res = await fetch(`${meetingUrl}/${meetingId}/countdown`),
                      json = await res.json(),
                      array = json.array || [json.year, json.month, json.day, json.hour, json.minutes, json.second].map((v) => (v || 0));
                return new Date(Date.UTC(...array)).getTime()
              } catch(e) {
                console.error(e)
              }
            },
            /**
             * @returns {object} retrieved - id mapped object of meetings
             **/
            getMeetings: async () => {
              try {
                const result = await fetch(meetingUrl),
                      retrieved = await result.json(),
                      meetings = {},
                      mappings = {};

                const ids = retrieved.meetings.map((meeting) => {
                  meeting = mapMeetingProps(meeting);
                  meetings[meeting.id] = meeting;
                  mappings[meeting.id] = meeting.id;

                  [ 'date', 'time' ].map(function(k){
                    mappings[meeting[k]] = meeting.id;
                    mappings[meeting[k].toLowerCase()] = meeting.id;

                    return k;
                  })

                  return meeting.id
                })

                ids.sort((a, b) => Spaceship.operator(meetings[a], meetings[b], [ 'date', 'time' ]))

                this.setState({
                  ids,
                  meetings,
                  mappings,
                  version: retrieved.version,
                  loaded: true
                })

                return {...meetings}

              } catch (e) {
                console.error(e)
                this.setState({
                  meetings: {},
                  version: '',
                  loaded: false
                })

                return {}
              }
            },
            find: (val) => this.state.meetings[this.state.mappings[val]]
          }
        }}
      >
        {this.props.children}
      </Meeting.Context.Provider>
    )
  }
}
