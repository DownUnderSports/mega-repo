import React, {createContext, Component} from 'react'
import { objectOf, arrayOf, func, shape, string, number, bool } from 'prop-types'
import { Spaceship }  from 'react-component-templates/helpers'

const nationalityUrl = '/api/nationalities/'

export const Nationality = {}

Nationality.hydrationParamsKey = 'nationalitiesListContext'

Nationality.DefaultValues = {
  ids: [],
  loaded: false,
  mappings: {},
  nationalities: {},
}

Nationality.Context = createContext({
  nationalityState: {...Nationality.DefaultValues},
  nationalityActions: {
    getNationalities(){},
    getNationality(){},
    find(){},
  }
})

Nationality.Decorator = function withNationalityContext(Component) {
  return (props) => (
    <Nationality.Context.Consumer>
      {nationalityProps => <Component {...props} {...nationalityProps} />}
    </Nationality.Context.Consumer>
  )
}

Nationality.nationalityShape = () => shape({
  id: number.isRequired,
  loaded: bool,
  code: string.isRequired,
  country: string.isRequired,
  nationality: string.isRequired,
})

Nationality.PropTypes = {
  nationalityState: shape({
    ids: arrayOf(number),
    loaded: bool,
    mappings: objectOf(number),
    nationalities: objectOf(
      Nationality.nationalityShape()
    ),
  }),
  nationalityActions: shape({
    getNationalities: func,
    getNationality: func,
    find: func,
  }).isRequired
}

const mapNationalityProps = (nationality, show = false) => ({
  id:               +nationality.id,
  loaded:           !!show,
  code:             nationality.code,
  country:          nationality.country,
  nationality:      nationality.nationality,
  value:            nationality.id,
  label:            `${nationality.country} (${nationality.code})`,
  nationalityLabel: `${nationality.nationality} (${nationality.code})`,
})

export default class ReduxNationalityProvider extends Component {
  state = window.ssrHydrationParams[Nationality.hydrationParamsKey] || { ...Nationality.DefaultValues }

  componentDidUpdate() {
    if(window.shouldMakeHydrationParamsPublic) {
      window.ssrHydrationParams[Nationality.hydrationParamsKey] = this.state
    }
  }

  render() {
    return (
      <Nationality.Context.Provider
        value={{
          nationalityState: this.state,
          nationalityActions: {
            /**
             * @returns {object} retrieved - id mapped object of states
             **/
            getNationalities: async () => {
              try {
                const result = await fetch(nationalityUrl),
                      retrieved = await result.json(),
                      nationalities = {},
                      mappings = {}

                const ids = retrieved.map((nationality) => {
                  nationality = mapNationalityProps(nationality)
                  nationalities[nationality.id] = nationality

                  mappings[nationality.id] = nationality.id;

                  [ 'code', 'country', 'nationality' ].map(function(k){
                    mappings[nationality[k]] = nationality.id
                    mappings[nationality[k].toLowerCase()] = nationality.id
                    return void(0)
                  })

                  return nationality.id
                })

                ids.sort((a, b) => Spaceship.operator(nationalities[a], nationalities[b], ['code', 'country', 'nationality']))

                this.setState({
                  ids,
                  nationalities,
                  mappings,
                  loaded: true
                })

                return {...nationalities}

              } catch (e) {
                this.setState({
                  nationalities: {},
                  loaded: true
                })

                return {}
              }
            },
            getNationality: async (id) => {
              try {
                const result = await fetch(nationalityUrl + id),
                      nationality = await result.json(),
                      currentState = {...this.state.nationalities},
                      retrieved = mapNationalityProps(nationality, true)

                currentState[retrieved.id] = retrieved

                this.setState({
                  nationalities: currentState,
                  loaded: true
                })


                return {...retrieved}

              } catch (e) {
                console.error(e)
                const currentState = {...this.state.nationalities},
                      nationality = currentState[this.state.mappings[id]]

                nationality.loaded = 'failed'

                this.setState({
                  nationalities: currentState,
                  loaded: true
                })
                return {}
              }
            },
            find: (val) => this.state.nationalities[this.state.mappings[val]]
          }
        }}
      >
        {this.props.children}
      </Nationality.Context.Provider>
    )
  }
}
