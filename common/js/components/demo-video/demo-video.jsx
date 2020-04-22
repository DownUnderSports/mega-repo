import BasicVideo from 'common/js/components/basic-video'

export const demoVideoUrl = 'https://www.youtube.com/embed/Yh5CjpY35BM?autoplay=1&mute=1&rel=0&enablejsapi'
export const gbrVideoUrl= 'https://www.youtube.com/embed/C-gkKvFNL88?autoplay=1&mute=1&rel=0&enablejsapi'

export default class DemoVideo extends BasicVideo {
  state = {
    playing: false,
    className: '',
    url: demoVideoUrl,
    firstLoop: false
  }

  get startMuted() {
    return true
  }

  shouldStartOnMount = () => true

  onEnded = () => {
    console.log(this.state.url)
    return (this.state.url === demoVideoUrl)
      ? this.setStateIfMounted({ className: '', url: gbrVideoUrl }, this.setStarted)
      : this.setStateIfMounted({ className: this.props.loop || 'ended', url: demoVideoUrl }, this.setStopped)
  }

  onReady = () => this.state.firstLoop || this.setStateIfMounted({firstLoop: true }, this.setStarted)
}
