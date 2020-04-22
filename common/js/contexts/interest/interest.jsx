import React, {createContext, Component} from 'react'
import { objectOf, arrayOf, func, shape, string, number, bool } from 'prop-types'

const interestUrl = '/admin/interests/'

export const Interest = {}

Interest.DefaultValues = {
  ids: [],
  loaded: false,
  mappings: {},
  interests: {},
}

Interest.Context = createContext({
  interestState: {...Interest.DefaultValues},
  interestActions: {
    getInterests(){},
    find(){},
  }
})

Interest.Decorator = function withInterestContext(Component) {
  return (props) => (
    <Interest.Context.Consumer>
      {interestProps => <Component {...props} {...interestProps} />}
    </Interest.Context.Consumer>
  )
}

Interest.stateShape = () => shape({
  id: number.isRequired,
  level: string.isRequired,
  contactable: bool,
})

Interest.PropTypes = {
  interestState: shape({
    loaded: bool,
    ids: arrayOf(number),
    mappings: objectOf(number),
    interests: objectOf(
      Interest.stateShape()
    ),
  }),
  interestActions: shape({
    getInterests: func,
    find: func,
  }).isRequired
}

const mapInterestProps = (interest) => ({
  id: +interest.id,
  level: interest.level,
  contactable: !!interest.contactable,
})

export default class ReduxInterestProvider extends Component {
  state = { ...Interest.DefaultValues }

  render() {
    return (
      <Interest.Context.Provider
        value={{
          interestState: this.state,
          interestActions: {
            /**
             * @returns {object} retrieved - id mapped object of interests
             **/
            getInterests: async () => {
              try {
                const result = await fetch(interestUrl),
                      retrieved = await result.json(),
                      interests = {},
                      mappings = {}

                const ids = retrieved.map((interest) => {
                  interest = mapInterestProps(interest)
                  const fWord = interest.level.split(' ')[0]

                  interests[interest.id] = interest;
                  mappings[interest.id] = interest.id;
                  mappings[interest.level] = interest.id;
                  mappings[interest.level.toLowerCase()] = interest.id;
                  mappings[fWord] = interest.id;
                  mappings[fWord.toLowerCase()] = interest.id;

                  return interest.id
                })

                this.setState({
                  ids,
                  interests,
                  mappings,
                  loaded: true
                })

                return {...interests}

              } catch (e) {
                console.error(e)
                this.setState({
                  interests: {},
                  loaded: false
                })

                return {}
              }
            },
            find: (val) => this.state.interests[this.state.mappings[val]]
          }
        }}
      >
        {this.props.children}
      </Interest.Context.Provider>
    )
  }
}
