import React, { Component } from 'react';
import { StaffUsers } from 'common/js/contexts/staff-users';
import { Objected } from 'react-component-templates/helpers'
import { SelectField } from 'react-component-templates/form-components';

export default class StaffUserSelectField extends Component {
  static contextType = StaffUsers.Context

  constructor(props){
    super(props)
    this.state = {
      options: []
    }
  }

  async componentDidMount(){
    this._isMounted = true
    try {
      return await (this.context.staffUsersState.loaded ? Promise.resolve() : this.context.staffUsersActions.getStaffUsers())
      .then(this.mapOptions)
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate() {
    const { loaded = false, options = [] } = this.state
    if(
      (!loaded && this.context.staffUsersState.loaded) ||
      (options.length !== this.context.staffUsersState.ids.length)
    ) {
      this.mapOptions()
    }
  }

  componentWillUnmount() {
    this._isMounted = false
  }

  mapOptions = () => {
    if(!this._isMounted) return false
    const { staffUsersState: { loaded = false }, staffUsersActions: {toArray = (() => [])} } = this.context;
    this.setState({
      loaded,
      options: toArray((staffUser) => ({
        id: staffUser.id,
        value: staffUser.id,
        label: staffUser.name,
      }))
    })
  }

  render() {
    return (
      <SelectField
        filterOptions={{
          indexes: ['name'],
        }}
        {...Objected.filterKeys(this.props, ['staffUsersState', 'staffUsersActions'])}
        options={this.state.options}
      />
    )
  }
}
