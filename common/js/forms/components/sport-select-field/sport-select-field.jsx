import React, { Component } from 'react';
import { Sport } from 'common/js/contexts/sport';
import { Objected } from 'react-component-templates/helpers'
import { SelectField } from 'react-component-templates/form-components';

export default class SportSelectField extends Component {
  static contextType = Sport.Context

  constructor(props){
    super(props)
    this.state = {
      options: []
    }
  }

  async componentDidMount(){
    this._isMounted = true
    try {
      return await (this.context.sportState.loaded ? Promise.resolve() : this.context.sportActions.getSports())
      .then(this.mapOptions)
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate(){
    if(!this._isMounted) return false
    const { loaded = false, options = [] } = this.state
    if(
      (!loaded && this.context.sportState.loaded) ||
      (options.length !== this.context.sportState.ids.length)
    ) {
      this.mapOptions()
    }
  }

  componentWillUnmount() {
    this._isMounted = false
  }

  mapOptions = () => {
    if(!this._isMounted) return false

    const { sportState: { ids = [], loaded = false }, sportActions: {find = ((v) => v)} } = this.context,
          options = ids.map((id) => find(id)).map((sport) => ({
            id: sport.id,
            value: sport.id,
            label: sport.fullGender,
            abbr: sport.abbrGender,
          }))

    this.setState({
      loaded,
      options,
      clientOptions: options.filter(opt => !/^(STF?|CH)$/.test(opt.abbr))
    })
  }

  render() {
    return (
      <SelectField
        {...Objected.filterKeys(this.props, ['sportState', 'sportActions'])}
        options={this.props.clientOnly ? this.state.clientOptions : this.state.options}
        filterOptions={{
          indexes: ['abbr','label'],
        }}
      />
    )
  }
}
