import { Component } from 'react'

import supportsNativeSmoothScroll from 'common/js/helpers/supports-native-smooth-scroll'

export default class LocationChange extends Component {
  async componentDidMount(){
    this.scrollUpdate()
  }

  componentWillUnmount() {
    this.scrollCount = 0
    this.scrolled = false
    clearTimeout(this.scroller)
  }

  shouldComponentUpdate(nextProps) {
    console.log(nextProps)
    if(!this.props || !this.props.history || nextProps.history.action === "PUSH") this.scrollUpdate(((nextProps || {}).history || {}).action === "PUSH")
    return false
  }

  // componentDidUpdate(prevProps) {
  //   console.log(prevProps)
  //   if(!prevProps.history || prevProps.history.action === "PUSH") this.scrollUpdate()
  // }

  get hash() {
    return ((this.props.location || {}).hash || '')
  }

  scroll = (hash) => {
    this.scrollCount = this.scrollCount + 1
    if(!this.scrolled && (this.hash === hash)) {
      if(document.querySelector(hash)){
        this.scrolled = true
        this.scroller = setTimeout(() => {
          document.querySelector(hash).scrollIntoView();
          window.scrollBy(0, -100)
        }, 100)
      } else {
        if(this.scrollCount < 1800) this.scroller = setTimeout(() => this.scroll(hash), 100)
      }
    }
  }

  scrollUpdate = (push = false) => {
    clearTimeout(this.scroller)

    try {
      if(this.hash) {
        this.scrollCount = 0
        this.scrolled = false

        this.scroll(this.hash)
      } else {
        let top = 0
        if(push) {
          let el = document.getElementById('site-header-content')

          if(el) top = el.offsetTop || 0
          else {
            el = document.getElementById('site-carousel')
                || document.getElementById('site-banner-video')

            if(el) top = el.offsetHeight + el.offsetTop
          }
        }

        // if((window.scrollY || 0) > 0) {
          supportsNativeSmoothScroll ? window.scrollTo({ top, left: 0, behavior: 'smooth' }) : window.scrollTo(0, 0)
        // }

      }
    } catch (e) {
      console.error(e)
    }
  }

  render () {
    return false
  }
}
