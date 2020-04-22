import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import { DisplayOrLoading } from 'react-component-templates/components';
import VideoViewInfo from 'components/video-view-info'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'


const viewsUrl = '/admin/users/:user_id/video_views.json'

export default class VideoViews extends AsyncComponent {
  constructor(props) {
    super(props)
    this.state = { views: [], loading: true }
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.afterMount()
  }

  mainKey = () => this.props.id
  url = (id) => viewsUrl.replace(':user_id', id)
  defaultValue = () => ({
    views: [],
  })

  capitalize(str) {
    return str[0].toUpperCase() + str.slice(1)
  }

  removeView = (i) => {
    const {views = []} = this.state
    this.setState({views: [...views.slice(0, i), ...views.slice(i + 1)]})
  }

  addView = () => this.setState({
    views: [
      ...this.state.views,
      { user_id: this.props.id }
    ]
  })

  render() {
    const {
      views = [],
      loading = false,
    } = this.state || {}

    return (
      <DisplayOrLoading
        display={!loading}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        {
          (views || []).map((r, k) => (
            <VideoViewInfo
              key={k}
              onSuccess={() => this.afterMount()}
              onCancel={ !r.id && (() => this.removeView(k))}
              {...r}
            />
          ))
        }
        <button className='btn-block btn-primary' onClick={this.addView}>
          Add Video
        </button>
      </DisplayOrLoading>
    );
  }
}
