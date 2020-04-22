import React, {createContext, Component} from 'react'
import { arrayOf, func, shape, string, bool } from 'prop-types'

const homeGalleryUrl = '/api/home_gallery/'

export const HomeGallery = {}

HomeGallery.DefaultValues = {
  loaded: false,
  imageList: [],
}

HomeGallery.Context = createContext({
  homeGalleryImagesState: {...HomeGallery.DefaultValues},
  homeGalleryImagesActions: {
    getHomeGallery(){},
  }
})

HomeGallery.Decorator = function withHomeGalleryContext(Component) {
  return (props) => (
    <HomeGallery.Context.Consumer>
      {stateProps => <Component {...props} {...stateProps} />}
    </HomeGallery.Context.Consumer>
  )
}

HomeGallery.stateShape = () => shape({
  thumbnail: string.isRequired,
  full: string.isRequired,
})

HomeGallery.PropTypes = {
  homeGalleryImagesState: shape({
    loaded: bool,
    imageList: arrayOf(
      HomeGallery.stateShape()
    ),
  }),
  homeGalleryImagesActions: shape({
    getHomeGallery: func,
  }).isRequired
}

const mapHomeGalleryImageProps = (img, show = false) => ({
  thumbnail: img.thumbnail,
  full: img.full,
  alt: img.alt,
})

export default class ReduxStateProvider extends Component {
  state = { ...HomeGallery.DefaultValues }

  render() {
    return (
      <HomeGallery.Context.Provider
        value={{
          homeGalleryImagesState: this.state,
          homeGalleryImagesActions: {
            /**
             * @returns {array} retrieved - mapped array of homeGalleryImages
             **/
            getHomeGallery: async () => {
              try {
                const result = await fetch(homeGalleryUrl),
                      retrieved = await result.json(),
                      imageList = retrieved.map(mapHomeGalleryImageProps)

                this.setState({
                  imageList,
                  loaded: true
                })

                return [...imageList]

              } catch (e) {
                this.setState({
                  imageList: [],
                  loaded: false
                })

                return []
              }
            },
          }
        }}
      >
        {this.props.children}
      </HomeGallery.Context.Provider>
    )
  }
}
