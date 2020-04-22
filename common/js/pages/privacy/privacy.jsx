import React, { PureComponent } from 'react'
import Privacy from 'common/js/components/privacy'
import SiteSeal from 'common/js/components/site-seal'
import pixelTracker from 'common/js/helpers/pixel-tracker'
import './privacy.css'

export default class PrivacyPage extends PureComponent {
  componentDidMount() {
    this.scrollCount = 0

    try {
      pixelTracker('track', 'PageView')
      if(this.hash) {
        this.scroll()
      }
    } catch (e) {
      console.error(e)
    }
  }

  componentWillUnmount() {
    this.scrollCount = 0
    this.scrolled = false
    clearTimeout(this.scroller)
  }

  get hash() {
    return ((this.props.location || {}).hash || '')
  }

  scroll = () => {
    console.log(this.hash)
    this.scrollCount = this.scrollCount + 1
    if(!this.scrolled) {
      if(document.querySelector(this.hash)){
        this.scrolled = true
        this.scroller = setTimeout(() => {
          document.querySelector(this.hash).scrollIntoView();
          window.scrollBy(0, -100)
        }, 100)
      } else {
        if(this.scrollCount < 1800) this.scroller = setTimeout(this.scroll, 100)
      }
    }
  }

  render() {
    return (
      <>

        <Privacy
          key="Privacy"
          className='my-5 bg-light border rounded p-3'
        />
        <SiteSeal
          key="SiteSeal"
          className="privacy-site-seal"
        />
      </>
    )
  }
}
