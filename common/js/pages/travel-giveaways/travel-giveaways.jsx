import React, { PureComponent } from 'react'
import TravelGiveawayTerms from 'common/js/components/terms/travel-giveaways'
import pixelTracker from 'common/js/helpers/pixel-tracker'
import './travel-giveaways.css'

export default class TravelGiveawaysTermsPage extends PureComponent {
  componentDidMount() {
    try {
      pixelTracker('track', 'PageView')
      if(this.props.location.hash) {
        this.scroll()
      }
    } catch (e) {
      console.error(e)
    }
  }

  componentWillUnmount() {
    this.scrolled = false
    clearTimeout(this.scroller)
  }

  scroll = () => {
    console.log(document.querySelector(this.props.location.hash), this.props.location.hash)
    if(!this.scrolled) {
      if(document.querySelector(this.props.location.hash)){
        this.scrolled = true
        this.scroller = setTimeout(() => {
          document.querySelector(this.props.location.hash).scrollIntoView();
          console.log(window.scrollBy(0, -100))
        }, 100)
      } else {
        this.scroller = setTimeout(this.scroll, 100)
      }
    }
  }

  render() {
    return (
      <TravelGiveawayTerms
        className='my-5 bg-light border rounded p-3'
        year="2021"
      />
    )
  }
}
