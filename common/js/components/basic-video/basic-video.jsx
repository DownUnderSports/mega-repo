import React, { Component } from 'react';
import YouTubePlayer from 'react-player/lib/players/YouTube'
import "./basic-video.css"

const dVidConfig = {
  playerVars: {
    modestbranding: 1,
    start: 0,
    // domain: window.location.origin,
    origin: window.location.origin,
    enablejsapi: 1,
    autoplay: 1
  },
  preload: true
}

export default class BasicVideo extends Component {
  state = {
    playing: false,
    className: '',
    url: ''
  }

  componentDidMount() {
    this._mounted = true
    this.afterMount()
  }

  componentWillUnmount() {
    this.setState({ playing: false })
    this._mounted = false
  }

  get url() {
    return this.props.url || this.state.url
  }

  get startMuted() {
    return !!this.props.autoplay
  }

  get displayClass() {
    return String(this.props.displayClass || '')
  }

  get playerState() {
    return String(this.state.className || (this.state.playing ? '' : this.props.baseState) || '')
  }

  afterMount = () => {
    setTimeout(() => {
      this.setStateIfMounted({ playing: this.shouldStartOnMount() })
    }, 3000)
  }

  setStateIfMounted = (...args) => this._mounted && this.setState(...args)

  setStarted = () =>
    this.setStateIfMounted({ playing: true, className: '' })

  setStopped = () =>
    this.props.loop
      ? this.setStarted()
      : this.setStateIfMounted({ playing: false, className: this.state.className || 'paused' })

  shouldStartOnMount = () => !!this.props.autoplay

  onReady = () =>
    console.log(`${this.url} ready`)

  onPlay = () =>
    this.setStateIfMounted({ playing: true }, this.setStarted)

  onDidPause = (ev) => {
    this.closeFullScreen()
    this.onPause(ev)
  }

  onPause = () =>
    this.setStateIfMounted({ className: 'paused' }, this.setStopped)

  onClick = (ev) => {
    this.state.playing ? this.onPause() : this.onPlay()
  }

  closeFullScreen = async () => {
    try {
      await (
        document.exitFullscreen
          ? document.exitFullscreen()
          : (
              document.mozCancelFullScreen
                ? document.mozCancelFullScreen()
                : (
                    document.webkitExitFullscreen
                      ? document.webkitExitFullscreen()
                      : Promise.resolve()
                  )
            )
      )
    } catch(_) {}
  }

  onDidEnd = (ev) => {
    this.closeFullScreen()
    this.onEnded(ev)
  }

  onEnded = () =>
    this.setStateIfMounted({ className: this.props.loop || 'ended' }, this.setStopped)

  onError = (ev) =>
    console.log(ev)

  /**
   * Render Youtube Video
   * @return {ReactElement} markup
   */
  render() {
    const { url: _, baseState: _b, displayClass: _d, autoplay: _a, ...props } = this.props
    return (
      <div {...props} className={`youtubeWrapper ${this.displayClass} ${this.playerState} responsive-video`} onClick={this.onClick}>
        <YouTubePlayer
          controls
          className='video-player'
          url={this.url}
          width='100%'
          height='100%'
          config={dVidConfig}
          onReady={this.onReady}
          onStart={this.onPlay}
          onPlay={this.onPlay}
          onPause={this.onDidPause}
          onEnded={this.onDidEnd}
          onError={this.onError}
          playing={this.state.playing}
          volume={this.startMuted ? 0 : null}
          muted={this.startMuted}
        />
        {!this.state.playing && <img className="random-background-image" src={`/random-background?${Number(new Date())}`} alt="Video Overlay"/> }
      </div>
    )
  }
}
