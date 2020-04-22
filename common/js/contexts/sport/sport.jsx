import React, {createContext, Component} from 'react'
import { objectOf, arrayOf, func, shape, string, number, bool } from 'prop-types'
import { Spaceship }  from 'react-component-templates/helpers'

const sportUrl = '/api/sports/'

export const Sport = {}

Sport.hydrationParamsKey = 'sportsListContext'

Sport.DefaultValues = {
  ids: [],
  loaded: false,
  mappings: {},
  sports: {},
}

Sport.Context = createContext({
  sportState: {...Sport.DefaultValues},
  sportActions: {
    getSports(){},
    getSport(){},
    find(){},
  }
})

Sport.Decorator = function withSportContext(Component) {
  return (props) => (
    <Sport.Context.Consumer>
      {sportProps => <Component {...props} {...sportProps} />}
    </Sport.Context.Consumer>
  )
}

Sport.sportShape = () => shape({
  id: number.isRequired,
  loaded: bool,
  abbr: string.isRequired,
  full: string.isRequired,
  abbrGender: string.isRequired,
  fullGender: string.isRequired,
  info: shape({
    title: string,
    tournament: string,
    firstYear: number,
    departingDates: string,
    teamCount: string,
    teamSize: string,
    description: string,
    bulletPoints: arrayOf(string),
    programs: arrayOf(string),
    backgroundImage: string,
    additional: string,
  }).isRequired
})

Sport.PropTypes = {
  sportState: shape({
    ids: arrayOf(number),
    loaded: bool,
    mappings: objectOf(number),
    sports: objectOf(
      Sport.sportShape()
    ),
  }),
  sportActions: shape({
    getSports: func,
    getSport: func,
    find: func,
  }).isRequired
}

const mapSportProps = (sport, show = false) => ({
  id: +sport.id,
  loaded: !!show,
  abbr: sport.abbr,
  full: sport.full,
  abbrGender: sport.abbr_gender,
  fullGender: sport.full_gender,
  info: sport.info ? {
    title: sport.info.title,
    tournament: sport.info.tournament,
    firstYear: sport.info.first_year,
    departingDates: sport.info.departing_dates,
    returningDates: sport.info.returning_dates,
    teamCount: sport.info.team_count,
    teamSize: sport.info.team_size,
    description: sport.info.description,
    bulletPoints: sport.info.bullet_points_array,
    programs: sport.info.programs_array,
    backgroundImage: sport.info.background_image,
    additional: sport.info.additional,
  } : {},
})

export default class ReduxSportProvider extends Component {
  state = window.ssrHydrationParams[Sport.hydrationParamsKey] || { ...Sport.DefaultValues }

  componentDidUpdate() {
    if(window.shouldMakeHydrationParamsPublic) {
      window.ssrHydrationParams[Sport.hydrationParamsKey] = this.state
    }
  }

  render() {
    return (
      <Sport.Context.Provider
        value={{
          sportState: this.state,
          sportActions: {
            /**
             * @returns {object} retrieved - id mapped object of states
             **/
            getSports: async () => {
              try {
                const result = await fetch(sportUrl),
                      retrieved = await result.json(),
                      sports = {},
                      mappings = {}

                const ids = retrieved.map((sport) => {
                  sport = mapSportProps(sport)
                  sports[sport.id] = sport

                  mappings[sport.id] = sport.id;

                  [ 'abbrGender', 'fullGender' ].map(function(k){
                    mappings[sport[k]] = sport.id
                    mappings[sport[k].toLowerCase()] = sport.id
                    return void(0)
                  })

                  return sport.id
                })

                ids.sort((a, b) => Spaceship.operator(sports[a], sports[b], ['full', 'fullGender', 'abbr', 'abbrGender']))

                this.setState({
                  ids,
                  sports,
                  mappings,
                  loaded: true
                })

                return {...sports}

              } catch (e) {
                this.setState({
                  sports: {},
                  loaded: true
                })

                return {}
              }
            },
            getSport: async (id) => {
              try {
                const result = await fetch(sportUrl + id),
                      sport = await result.json(),
                      currentState = {...this.state.sports},
                      retrieved = mapSportProps(sport, true)

                currentState[retrieved.id] = retrieved

                this.setState({
                  sports: currentState,
                  loaded: true
                })


                return {...retrieved}

              } catch (e) {
                console.error(e)
                const currentState = {...this.state.sports},
                      sport = currentState[this.state.mappings[id]]

                sport.loaded = 'failed'

                this.setState({
                  sports: currentState,
                  loaded: true
                })
                return {}
              }
            },
            find: (val) => this.state.sports[this.state.mappings[val]]
          }
        }}
      >
        {this.props.children}
      </Sport.Context.Provider>
    )
  }
}
