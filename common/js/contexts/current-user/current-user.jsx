import React, {createContext, Component} from 'react'
import { arrayOf, func, shape, string, number, bool } from 'prop-types'
//import authFetch from 'common/js/helpers/auth-fetch'

const userUrl = '/api/users/current'

export const CurrentUser = {}

const getCookie = function(name) {
  var match = document.cookie.match(new RegExp('(^| )' + name + '=([^;]+)'));
  if (match) return match[2];
}

CurrentUser.DefaultValues = {
  id: null,
  loaded: false,
  staff: false,
  statusChanged: false,
  permissions: {},
  attributes: {},
}

CurrentUser.Context = createContext({
  currentUserState: {...CurrentUser.DefaultValues},
  currentUserActions: {
    getCurrentUser(){},
  }
})

CurrentUser.Decorator = function withCurrentUserContext(Component) {
  return (props) => (
    <CurrentUser.Context.Consumer>
      {userProps => <Component {...props} {...userProps} />}
    </CurrentUser.Context.Consumer>
  )
}

CurrentUser.permissionsShape = () => shape({
  admin: bool,
  trusted: bool,
  australia: bool,
  finances: bool,
  flights: bool,
  recaps: bool,
  remittances: bool,
  uniforms: bool,
  userIds: arrayOf(number),
  dusIds: arrayOf(string)
})

CurrentUser.attributesShape = () => shape({
  id: number,
  dusId: string,
  category: string,
  email: string,
  phone: string,
  extension: string,
  canText: bool,
  title: string,
  first: string,
  middle: string,
  last: string,
  suffix: string,
  name: string,
  printNames: string,
  printFirstNames: string,
  printOtherNames: string,
  nickName: string,
  gender: string,
  shirtSize: string,
})

CurrentUser.PropTypes = {
  currentUserState: shape({
    id: number,
    loaded: bool,
    staff: bool,
    statusChanged: bool,
    permissions: CurrentUser.permissionsShape(),
    attributes: CurrentUser.attributesShape()
  }),
  currentUserActions: shape({
    getCurrentUser: func,
  }).isRequired
}

const mapCurrentUserProps = (user, show = false) => {
  const permissions = user.permissions || {},
        attributes = user.attributes || {}
  return {
    id: user.id ? +user.id : null,
    staff: !!user.staff,
    permissions: {
      admin: !!permissions.admin,
      trusted: !!permissions.trusted,
      australia: !!permissions.australia,
      finances: !!permissions.finances,
      flights: !!permissions.flights,
      recaps: !!permissions.recaps,
      remittances: !!permissions.remittances,
      uniforms: !!permissions.uniforms,
      userIds: permissions.user_ids || [],
      dusIds: permissions.dus_ids || [],
    },
    attributes: {
      id: +attributes.id,
      dusId: attributes.dus_id,
      category: attributes.category_title,
      email: attributes.email,
      phone: attributes.phone,
      extension: attributes.extension,
      title: attributes.title,
      first: attributes.first,
      middle: attributes.middle,
      last: attributes.last,
      suffix: attributes.suffix,
      name: attributes.full_name,
      printNames: attributes.print_names,
      printFirstNames: attributes.print_first_names,
      printOtherNames: attributes.print_other_names,
      nickName: attributes.nick_name,
      gender: attributes.gender,
      shirtSize: attributes.shirt_size,
    }
  }
}

export default class ReduxCurrentUserProvider extends Component {
  state = { ...CurrentUser.DefaultValues }

  componentDidMount() {
    window.document.addEventListener('authStatusChange', this.changeListener)
  }

  componentWillUnmount() {
    window.document.removeEventListener('authStatusChange', this.changeListener)
  }

  changeListener = () => this.setState({ statusChanged: true })

  render() {
    return (
      <CurrentUser.Context.Provider
        value={{
          currentUserState: this.state,
          currentUserActions: {
            /**
             * @returns {object} retrieved - id mapped object of user
             **/
            getCurrentUser: async () => {
              try {
                const result = await fetch(userUrl),
                      retrieved = await result.json(),
                      user = mapCurrentUserProps(retrieved),
                      cookieValue = getCookie('plain_id')


                if(String(cookieValue) !== String(user.id)) {
                  console.info('MISMATCHED SESSION!')
                }

                this.setState({
                  ...user,
                  statusChanged: false,
                  loaded: true
                })

                return {...user}

              } catch (e) {
                console.error(e)
                this.setState({
                  ...CurrentUser.DefaultValues
                })

                return {}
              }
            },
          }
        }}
      >
        {this.props.children}
      </CurrentUser.Context.Provider>
    )
  }
}
