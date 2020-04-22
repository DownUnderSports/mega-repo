import React, {createContext, Component} from 'react'
import { objectOf, arrayOf, func, shape, string, number, bool } from 'prop-types'
import { Spaceship }  from 'react-component-templates/helpers'

const videoUrl = '/api/videos'

export const Video = {}

Video.DefaultValues = {
  ids: [],
  version: '',
  loaded: false,
  mappings: {},
  videos: {},
}

Video.Context = createContext({
  videoState: {...Video.DefaultValues},
  videoActions: {
    checkVersion(){},
    getVideos(){},
    getVideoTime(){},
    find(){},
  }
})

Video.Decorator = function withVideoContext(Component) {
  return (props) => (
    <Video.Context.Consumer>
      {videoProps => <Component {...props} {...videoProps} />}
    </Video.Context.Consumer>
  )
}

Video.videoShape = () => shape({
  id: number.isRequired,
  date: string.isRequired,
  time: string.isRequired,
  category: string,
})

Video.PropTypes = {
  videoState: shape({
    loaded: bool,
    version: string,
    ids: arrayOf(number),
    mappings: objectOf(number),
    videos: objectOf(
      Video.videoShape()
    ),
  }),
  videoActions: shape({
    checkVersion: func,
    getVideos: func,
    find: func,
  }).isRequired
}

const mapVideoProps = (video, show = false) => {
  return {
    id: +video.id,
    link: video.link,
    category: video.category,
    duration: video.duration,
    sent: video.sent,
    viewed: video.viewed,
  }
}

export default class ReduxVideoProvider extends Component {
  state = { ...Video.DefaultValues }

  render() {
    return (
      <Video.Context.Provider
        value={{
          videoState: this.state,
          videoActions: {
            /**
             * @returns {boolean} upToDate - if video list is up to date
             **/
            checkVersion: async () => {
              try {
                if(!this.state.version) throw new Error('version not set')
                await fetch(`${videoUrl}/version/${this.state.version}`)
                return true
              } catch (e) {
                this.setState({
                  version: '',
                  loaded: false,
                })
                return false
              }
            },
            /**
             * @returns {object} retrieved - id mapped object of videos
             **/
            getVideos: async () => {
              try {
                const result = await fetch(videoUrl),
                      retrieved = await result.json(),
                      videos = {},
                      mappings = {};

                const ids = retrieved.videos.map((video) => {
                  video = mapVideoProps(video);
                  videos[video.id] = video;
                  mappings[video.id] = video.id;

                  [ 'link' ].map(function(k){
                    mappings[video[k]] = video.id;
                    mappings[video[k].toLowerCase()] = video.id;

                    return k;
                  })

                  return video.id
                })

                ids.sort((a, b) => Spaceship.operator(videos[a], videos[b], [ 'category', 'id' ]))

                this.setState({
                  ids,
                  videos,
                  mappings,
                  version: retrieved.version,
                  loaded: true
                })

                return {...videos}

              } catch (e) {
                console.error(e)
                this.setState({
                  videos: {},
                  version: '',
                  loaded: false
                })

                return {}
              }
            },
            find: (val) => this.state.videos[this.state.mappings[val]]
          }
        }}
      >
        {this.props.children}
      </Video.Context.Provider>
    )
  }
}
