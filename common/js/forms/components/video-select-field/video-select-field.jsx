import React, { Component } from 'react';
import { Video } from 'common/js/contexts/video';
import { Objected } from 'react-component-templates/helpers'
import { SelectField } from 'react-component-templates/form-components';

export default class VideoSelectField extends Component {
  static contextType = Video.Context

  constructor(props){
    super(props)
    this.state = {
      options: []
    }
  }

  async componentDidMount(){
    try {
      return await ((this.context.videoState.loaded && (await this.context.videoActions.checkVersion())) ? Promise.resolve() : this.context.videoActions.getVideos())
      .then(this.mapOptions)
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate(){
    const { loaded = false, options = [] } = this.state
    if(
      (!loaded && this.context.videoState.loaded) ||
      (options.length !== this.context.videoState.ids.length)
    ) {
      this.mapOptions()
    }
  }

  mapOptions = () => {
    const { videoState: { ids = [], loaded = false }, videoActions: {find = ((v) => v)} } = this.context;
    this.setState({
      loaded,
      options: ids.map((id) => find(id)).map((video) => ({
        id: video.id,
        value: video.id,
        label: `${video.category} - ${video.id} - ${video.link}`,
      })).reverse()
    })
  }

  render() {
    return (
      <SelectField
        {...Objected.filterKeys(this.props, ['videoState', 'videoActions'])}
        options={this.state.options}
        filterOptions={{
          indexes: ['label']
        }}
      />
    )
  }
}
