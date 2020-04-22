import React, {createContext, Component} from 'react'
import { Objected } from 'react-component-templates/helpers';
import { func, shape, string, number } from 'prop-types'
import headerImages from 'common/assets/images/headers'
import FetchQueue from 'common/js/helpers/fetch-queue'
// import canUseDOM from 'common/js/helpers/can-use-dom'

export const Background = {}
// let assetServer = '', origin = '';
//
// if(canUseDOM) {
//   try {
//     origin = window.location.origin
//     assetServer = document.getElementById('asset-server').value
//   } catch(_) {
//     assetServer = window.location.origin
//   }
// }

Background.DefaultValues = {
  imgIdx: 0,
  headerClassName: '',
  currentImage: {
    backgroundImage: `url(${headerImages[0]})`,
  },
  imageSrc: headerImages[0],
  nextImageSrc: headerImages[1],
  previousImageSrc: headerImages[headerImages.length - 1],
  running: false,
}

Background.Context = createContext({
  backgroundState: Objected.deepClone(Background.DefaultValues),
  backgroundActions: {
    nextBackground(){},
    previousBackground(){},
    setBackground(){},
    unsetBackground(){},
    loop(){},
    stopLoop(){},
  }
})

Background.Decorator = function withBackgroundContext(Component) {
  return (props) => (
    <Background.Context.Consumer>
      {backgroundProps => <Component {...props} {...backgroundProps} />}
    </Background.Context.Consumer>
  )
}

Background.PropTypes = {
  backgroundState: shape({
    imgIdx: number,
    headerClassName: string,
    currentImage: shape({
      backgroundImage: string,
    }),
    imageSrc: string,
    nextImageSrc: string,
    previousImageSrc: string,
  }),
  backgroundActions: shape({
    nextBackground: func,
    previousBackground: func,
    setBackground: func,
    unsetBackground: func,
    startLoop: func,
    stopLoop: func,
  }).isRequired
}

export default class ReduxBackgroundProvider extends Component {
  state = {...Background.DefaultValues}

  shouldChange = (source, stateChanges = {}, additionalStyles = {}) => {
    if(!this.imgSource || (this.imgSource !== source)) return true;

    if(stateChanges && (typeof stateChanges === 'object')) {
      if(!this.stateChanges) return true;
      for(let k in stateChanges) {
        if(stateChanges.hasOwnProperty(k) && (stateChanges[k] !== this.stateChanges[k])) return true
      }
    }

    if(additionalStyles && (typeof additionalStyles === 'object')) {
      if(!this.imgStyles) return true;
      for(let k in additionalStyles) {
        if(additionalStyles.hasOwnProperty(k) && (additionalStyles[k] !== this.imgStyles[k])) return true
      }
    }

    return false
  }

  /**
   * @returns {void} move to next or previous default background
   **/
  cycleBackground = (nextOrPreviousIdx, cb) => {
    if(this.bgChangeTimeout) clearTimeout(this.bgChangeTimeout)

    if(FetchQueue.runningCount) {
      return this.bgChangeTimeout = setTimeout(() => {
        this.nextBackground(cb)
      }, 7500)
    }

    const imgIdx = this[nextOrPreviousIdx](this.state.imgIdx),
          previousImageSrc = headerImages[this.previousIndex(imgIdx)],
          nextImageSrc = headerImages[this.nextIndex(imgIdx)];

    this.setBackground(
      headerImages[imgIdx],
      {
        imgIdx,
        previousImageSrc,
        nextImageSrc,
        headerClassName: ''
      },
      cb || this.loop
    )
  }

  /**
   * @returns {void} move to previous default background
   **/
  currentBackground = (cb) => {
    this.cycleBackground('currentIndex', cb)
  }

  /**
   * @returns {void} move to next default background
   **/
  nextBackground = (cb) => {
    this.cycleBackground('nextIndex', cb)
  }

  /**
   * @returns {void} move to previous default background
   **/
  previousBackground = (cb) => {
    this.cycleBackground('previousIndex', cb)
  }

  currentIndex(idx) {
    return !idx
      ? 0
      : (
          (idx < 0)
            ? (headerImages.length - 1)
            : (
                (idx > (headerImages.length - 1))
                  ? 0
                  : idx
              )
        )
  }

  nextIndex(idx) {
   return ((idx + 1) >= headerImages.length) ? 0 : (idx + 1)
  }

  previousIndex(idx) {
    return ((idx - 1) < 0) ? (headerImages.length - 1) : (idx - 1)
  }

  /**
   * @returns {void} set a background image
   **/
  setBackground = (source, stateChanges = {}, additionalStyles = {}, cb = (() => {})) => {
    if(this.shouldChange(source, stateChanges, additionalStyles)) {
      if(typeof additionalStyles === 'function'){
        cb = additionalStyles
        additionalStyles = {}
      }
      this.imgSource = source || 'dus-logo.png';
      this.stateChanges = stateChanges || {}
      this.imgStyles = additionalStyles || {}
      const img = new Image()

      this.img = img
      img.onload = () => {
        img.onload = null
        if(this.img === img) {
          this.setState({
            currentImage: {
              backgroundImage: `url(${img.src})`,
              ...(additionalStyles || {})
            },
            imageSrc: img.src,
            ...(stateChanges || {})
          }, cb)
        } else {
          cb()
        }
      }

      // console.log(this.imgSource)
      // this.img.src = `${assetServer}/${String(this.imgSource || '')}`.replace(origin, '')
      img.src = this.imgSource
    }
  }

  /**
   * @returns {void} loop header images
   **/
  loop = (time = 7500, firstTime) => {
    if(!this.loopStopped) {
      this.bgChangeTimeout = setTimeout(() => {
        this.nextBackground(this.loop)
      }, isNaN(firstTime) ? time : firstTime)
    }
  }

  /**
   * @returns {void} Start looping again
   **/
  startLoop = (time = 7500, firstTime) => {
    this.stopLoop()
    this.setState({
      ...Objected.deepClone(Background.DefaultValues),
      running: true
    })
    this.loopStopped = false
    this.loop(time, firstTime || 2500)
  }

  /**
   * @returns {void} stop looping images
   **/
  stopLoop = () => {
    this.setState({ running: false })
    this.loopStopped = true
    if(this.bgChangeTimeout) clearTimeout(this.bgChangeTimeout)
    if(this.img) this.img.onload = null
  }

  componentDidMount(){
    this.startLoop(7500, 0)
  }

  componentWillUnmount(){
    this.stopLoop()
  }

  render() {
    return (
      <Background.Context.Provider
        value={{
          backgroundState: this.state,
          backgroundActions: {
            nextBackground: this.nextBackground,
            previousBackground: this.previousBackground,
            setBackground: this.setBackground,
            startLoop: this.startLoop,
            stopLoop: this.stopLoop,
            unsetBackground: this.currentBackground,
          }
        }}
      >
        {this.props.children}
      </Background.Context.Provider>
    )
  }
}
