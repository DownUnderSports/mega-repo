import BasicVideo from 'common/js/components/basic-video'

const responseVideoUrl = 'https://www.youtube.com/embed/TV-W7bj9eu4?autoplay=0&mute=0&rel=0&enablejsapi'

export default class ResponseVideo extends BasicVideo {
  state = {
    playing: false,
    className: 'paused',
    url: responseVideoUrl,
    firstLoop: false
  }

  get startMuted() {
    return false
  }

  shouldStartOnMount = () => false

  onEnded = () =>
    this.setStateIfMounted({ className: 'ended' }, this.setStopped)
}
