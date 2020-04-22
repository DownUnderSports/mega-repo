import React, {createContext, Component} from 'react'
import { objectOf, arrayOf, func, shape, string, number, bool } from 'prop-types'
import { Spaceship }  from 'react-component-templates/helpers'

const staffUsersUrl = '/admin/users.json?category_type=staff&first=!automated'

export const StaffUsers = {}

StaffUsers.DefaultValues = {
  ids: [],
  loaded: false,
  mappings: {},
  staffUsers: {},
}

StaffUsers.Context = createContext({
  staffUsersState: {...StaffUsers.DefaultValues},
  staffUsersActions: {
    getStaffUserss(){},
    find(){},
  }
})

StaffUsers.Decorator = function withStaffUsersContext(Component) {
  return (props) => (
    <StaffUsers.Context.Consumer>
      {staffUsersProps => <Component {...props} {...staffUsersProps} />}
    </StaffUsers.Context.Consumer>
  )
}

StaffUsers.attributesShape = () => shape({
  id: number,
  dusId: string,
  staffId: number,
  title: string,
  first: string,
  middle: string,
  last: string,
  suffix: string,
  name: string,
})

StaffUsers.PropTypes = {
  staffUsersState: shape({
    loaded: bool,
    loading: bool,
    ids: arrayOf(number),
    mappings: objectOf(number),
    staffUsers: objectOf(
      StaffUsers.attributesShape()
    )
  }),
  staffUsersActions: shape({
    find: func,
    getStaffUsers: func,
    toArray: func
  }).isRequired
}

const mapStaffUserProps = (staffUser, show = false) => ({
  id: staffUser.id ? +staffUser.id : null,
  dusId: staffUser.dus_id,
  staffId: staffUser.category_id,
  title: staffUser.title,
  first: staffUser.first,
  middle: staffUser.middle,
  last: staffUser.last,
  suffix: staffUser.suffix,
  name: `${staffUser.first} ${staffUser.last}`,
})

const find = (context, val) => context.state.staffUsers[context.state.mappings[val]]
const toArray = (context, func) => context.state.ids.map((id) => func ? func(find(context, id)) : find(context, id))
const getStaffUsers = async (context) => {
  if(context.state.loading) {
    await context.state.loading()

    return context.state.staffUsers
  } else {
    const setStateAsync = (newState) => new Promise((res) => {
      context.setState(newState, () => res(context.state))
    })

    let promiseResolved

    await setStateAsync({loading: new Promise((res) => promiseResolved = res)})

    try {
      const result = await fetch(staffUsersUrl),
            retrieved = await result.json(),
            mappings = {},
            staffUsers = {},
            loaded = true

      const ids = (retrieved.users || []).map((staffUser) => {
        staffUser = mapStaffUserProps(staffUser)
        staffUsers[staffUser.id] = staffUser
        mappings[staffUser.id] = staffUser.id
        mappings[staffUser.first] = staffUser.id
        mappings[staffUser.name] = staffUser.id
        return staffUser.id
      }).sort((a, b) => Spaceship.operator(staffUsers[a], staffUsers[b], ['name', 'middle', 'suffix']))

      context.setState({
        ids,
        staffUsers,
        mappings,
        loaded,
        loading: false
      }, promiseResolved)

      return {...staffUsers}

    } catch (e) {
      context.setState({
        ...StaffUsers.DefaultValues,
        loaded: true,
        loading: false
      }, promiseResolved)

      return {}
    }
  }
}

export default class ReduxStaffUsersProvider extends Component {
  state = { ...StaffUsers.DefaultValues }

  render() {
    return (
      <StaffUsers.Context.Provider
        value={{
          staffUsersState: this.state,
          staffUsersActions: {
            /**
             * @returns {object} retrieved - id mapped object of staffUsers
             **/
            getStaffUsers: async () => await getStaffUsers(this),
            find: (val) => find(this, val),
            toArray: (func) => toArray(this, func),
          }
        }}
      >
        {this.props.children}
      </StaffUsers.Context.Provider>
    )
  }
}
