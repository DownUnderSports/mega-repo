import React, { Component } from 'react';
import { States } from 'common/js/contexts/states';
import { Objected } from 'react-component-templates/helpers'
import { SelectField } from 'react-component-templates/form-components';

export default class StateSelectField extends Component {
  static contextType = States.Context

  constructor(props){
    super(props)
    this.state = {
      options: []
    }
  }

  async componentDidMount(){
    try {
      return await (this.context.statesState.loaded ? Promise.resolve() : this.context.statesActions.getStates())
      .then(this.mapOptions)
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate() {
    const { loaded = false, options = [] } = this.state
    if(
      (!loaded && this.context.statesState.loaded) ||
      (options.length !== this.context.statesState.ids.length)
    ) {
      this.mapOptions()
    }
  }

  mapOptions = () => {
    const { statesState: { ids = [], loaded = false }, statesActions: {find = ((v) => v)} } = this.context;
    this.setState({
      loaded,
      options: ids.map((id) => find(id)).map((state) => ({
        value: state.id,
        label: state.full,
        abbr: state.abbr,
      }))
    })
  }

  render() {
    return (
      <SelectField
        {...Objected.filterKeys(this.props, ['statesState', 'statesActions'])}
        options={this.state.options}
        filterOptions={{
          indexes: ['abbr','label'],
          hotSwap: {
            indexes: ['abbr'],
            length: 1
          }
        }}
      />
    )
  }
}
