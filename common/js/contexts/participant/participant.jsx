import React, {createContext, Component} from 'react'
import { object, shape, func } from 'prop-types'

const participantUrl = '/api/participants'

export const Participant = {}

Participant.DefaultValues = {
  loaded: false,
  selected: 'all',
  all: [],
  queueCount: 0
}

Participant.Context = createContext({
  participantState: {...Participant.DefaultValues},
  participantActions: {
    getParticipants(){},
  }
})

Participant.Decorator = function withParticipantContext(Component) {
  return (props) => (
    <Participant.Context.Consumer>
      {participantProps => <Component {...props} {...participantProps} />}
    </Participant.Context.Consumer>
  )
}

Participant.PropTypes = {
  participantState: object,
  participantActions: shape({
    getParticipants: func,
  }).isRequired
}

export default class ReduxParticipantProvider extends Component {
  constructor(props) {
    super(props)
    this.state = { ...Participant.DefaultValues }
  }

  asyncSetState = (args) => new Promise((res) => {
    this.setState(args, res)
  })

  render() {
    return (
      <Participant.Context.Provider
        value={{
          participantState: this.state,
          participantActions: {
            /**
             * @returns {array} retrieved - array of participants
             **/
            getParticipants: async (selected = false) => {
              selected = selected || 'all'
              const queueCount = this.state.queueCount + 1,
                    holder = (this.state[selected] || []),
                    startState = {
                      loading: !holder.length,
                      loaded: !!holder.length,
                      selected,
                      queueCount
                    }

              if(startState.loading) startState[selected] = [];

              await this.asyncSetState(startState)

              if(startState.loaded) return holder

              try {
                if(this._fetchingParticipants) this._fetchingParticipants.abort()
                this._fetchingParticipants = fetch(`${participantUrl}${((/all/i).test(selected) ? '' : '/' + selected.toUpperCase())}`)
                const result = await this._fetchingParticipants,
                      retrieved = await result.json();



                this.asyncSetState({
                  loaded: true,
                  loading: false,
                  [selected]: retrieved.participants,
                })
              } catch(e) {
                console.error(e)
                this.asyncSetState({
                  loaded: true,
                  loading: false,
                  [selected]: [],
                })
              }
            },
          }
        }}
      >
        {this.props.children}
      </Participant.Context.Provider>
    )
  }
}
