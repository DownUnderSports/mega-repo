import React, { Component } from 'react';
import { Nationality } from 'common/js/contexts/nationality';
import { Objected } from 'react-component-templates/helpers'
import { SelectField } from 'react-component-templates/form-components';

export default class NationalitySelectField extends Component {
  static contextType = Nationality.Context

  constructor(props){
    super(props)
    this.state = {
      options: []
    }
  }

  async componentDidMount(){
    try {
      return await (this.context.nationalityState.loaded ? Promise.resolve() : this.context.nationalityActions.getNationalities())
      .then(this.mapOptions)
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate(){
    const { loaded = false, options = [] } = this.state
    if(
      (!loaded && this.context.nationalityState.loaded) ||
      (options.length !== this.context.nationalityState.ids.length)
    ) {
      this.mapOptions()
    }
  }

  mapOptions = () => {
    const {
      nationalityState:   { ids = [], loaded = false },
      nationalityActions: { find = (v => ({ id: v, value: v })) }
    } = this.context;

    this.setState({
      loaded,
      options: ids.map((id) => find(id))
    })
  }

  render() {
    return (
      <SelectField
        {...Objected.filterKeys(this.props, ['nationalityState', 'nationalityActions'])}
        options={this.state.options}
        filterOptions={{
          indexes: ['country', 'nationality', 'label', 'nationalityLabel'],
          hotSwap: {
            indexes: ['code', 'country', 'nationality', 'label', 'nationalityLabel'],
            length: 2
          }
        }}
      />
    )
  }
}
