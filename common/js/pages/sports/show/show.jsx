import React, { Component } from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';

import SportBulletPoints from 'common/js/components/sport/bullet-points';
import SportDescription from 'common/js/components/sport/description';
import SportInfo from 'common/js/components/sport/info';
import SportPoster from 'common/js/components/sport/poster';
import SportPrograms from 'common/js/components/sport/programs';
import BasicVideo from 'common/js/components/basic-video'

import { Sport } from 'common/js/contexts/sport'
// import { Background } from 'common/js/contexts/background'

import pixelTracker from 'common/js/helpers/pixel-tracker'

// import logo from 'common/assets/images/dus-logo.png'

const PromoVideos = {
  BB: "IVFjarUcsSk",
  FB: "MNvdUsIKXYQ",
  GF: "UdLmplVpIK0",
  TF: "nZPzBixtFpk",
  XC: "0rZ72uVFRps",
}

class SportPage extends Component {
  async fetchSport(props) {
    try {
      if(props.sportState.loaded) {
        const { sport, sportId } = this.sportFromProps(props)
        await sport.loaded ? Promise.resolve() : props.sportActions.getSport(sportId)
      } else {
        await props.sportActions.getSports().then(this.fetchSport)
      }
    } catch (e) {
      console.error(e)
    }
  }
  /**
   * Fetch Sport On Mount
   *
   * @private
   */
  async componentDidMount(){
    // this.props.backgroundActions.stopLoop()
    // this.props.backgroundActions.setBackground(
    //   logo,
    //   {},
    //   {backgroundSize: 'contain', transitionDuration: '.2s'}
    // )
    // this.props
    //   .backgroundActions
    //   .setBackground(
    //     logo,
    //     { headerClassName: 'd-none' },
    //     { backgroundSize: 'contain', transitionDuration: '.2s' }
    //   )
    pixelTracker('track', 'PageView')
    const {sport} = this.sportFromProps(this.props)
    if(sport.id) await this.fetchSport(this.props)

    const navTrigger = window.document.getElementById('sport-page-nav-trigger')
    navTrigger && (navTrigger.checked = false)
  }

  componentWillUnmount(){
    // this.props.backgroundActions.startLoop(7500, 0)
  }

  async componentDidUpdate(props){
    const oldProps = this.sportFromProps(props)
    const newProps = this.sportFromProps(this.props)
    if(newProps.sport.id) {
      if((oldProps.sportId !== newProps.sportId) || (newProps.sport.abbr && !newProps.sport.loaded)) await this.fetchSport(this.props)
      // if(
      //   newProps.sport.info &&
      //   newProps.sport.info.backgroundImage &&
      //   (
      //     this.currentImgSource !== newProps.sport.info.backgroundImage
      //   )
      // ) {
      //   this.currentImgSource = newProps.sport.info.backgroundImage;
      //   this.props
      //   .backgroundActions
      //   .setBackground(
      //     newProps.sport.info.backgroundImage,
      //     {},
      //     {backgroundSize: 'contain', transitionDuration: '.2s'}
      //   )
      // }
    }
  }

  sportFromProps(props) {
    let sportId = ((props.match || {}).params || {}).sportId

    return ({
      sportId,
      sport: props.sportActions.find(sportId) || {}
    })
  }

  renderFull() {
    const { sport } = this.sportFromProps(this.props),
          hyphenated = (sport && sport.full && sport.full.toLowerCase().replace(/\s/g, "-")) || ''

    if(!sport.id || (sport.loaded === 'failed')) {
      return (
        <article className={`row sport-page text-danger`}>
          <header className='col-12 page-header text-danger'><h3>Sport Not Found</h3></header>
          <div className="col sport-body text-center">
            Please select a sport from the options above<br/>
            <i><strong>If you believe you have reached this message in error, please refresh the page</strong></i>
          </div>
        </article>
      )
    }

    return (
      <DisplayOrLoading display={!!this.props.sportState.loaded && !!sport.loaded}>
        <article className={`row sport-page ${hyphenated}-page`}>
          <header className='col-12 page-header'><h3>{sport.name}</h3></header>
          <div className="col sport-body">
            {
              sport.live_results && (
                <div className='row'>
                  <div className="col-12 text-center">
                    LIVE RESULTS
                  </div>
                  <div className='col-12 form-group' dangerouslySetInnerHTML={{__html: sport.live_results}} />
                </div>
              )
            }
            <div className="row">
              <div className="col d-none d-md-block">
                <div className="row form-group">
                  <div className="col">
                    <SportPoster sportName={hyphenated} />
                  </div>
                </div>
                <div className="row form-group">
                  <div className="col">
                    <SportPrograms sport={sport} sportName={hyphenated} />
                  </div>
                </div>
              </div>
              <div className="col sport-content">
                <div className="row">
                  <div className="col">
                    <SportInfo sport={sport} />
                  </div>
                </div>
                <hr/>
                <div className="row">
                  <div className="col">
                    <SportBulletPoints sport={sport} />
                  </div>
                </div>
                <div className="row form-group">
                  <div className="col d-md-none">
                    <hr/>
                    <SportPrograms sport={sport} sportName={hyphenated} />
                  </div>
                </div>
                <hr/>
                <div className="row form-group">
                  <div className="col">
                    <SportDescription sport={sport} />
                  </div>
                </div>
              </div>
            </div>
            <div className="row form-group">
              {
                sport.additional && (<div className="col header-margins center-headers">
                  <hr/>
                  {
                    this.mapMarkdownLines(sport.additional)
                  }
                </div>)
              }
            </div>
            <div className='clearfix'></div>
          </div>
        </article>
      </DisplayOrLoading>
    )
  }

  render() {
    const { sport } = this.sportFromProps(this.props),
          hyphenated = (sport && sport.full && sport.full.toLowerCase().replace(/\s/g, "-")) || '',
          promo = !!PromoVideos[sport.abbr] && PromoVideos[sport.abbr]

    if(!sport.id || (sport.loaded === 'failed')) {
      return (
        <article className={`row sport-page text-danger`}>
          <header className='col-12 page-header text-danger'><h3>Sport Not Found</h3></header>
          <div className="col sport-body text-center">
            Please select a sport from the options above<br/>
            <i><strong>If you believe you have reached this message in error, please refresh the page</strong></i>
          </div>
        </article>
      )
    }

    return (
      <DisplayOrLoading display={!!this.props.sportState.loaded && !!sport.loaded}>
        <article className={`row sport-page ${hyphenated}-page`}>
          <header className='col-12 page-header'><h3>{sport.name}</h3></header>
          <div className="col sport-body">
            <div className="row">
              <div className="col-md">
                <div className="d-none d-md-block">
                  <SportPoster sportName={hyphenated} />
                </div>
              </div>
              <div className="col-md sport-content">
                <SportInfo sport={sport} />
                <hr/>
                {
                  promo && (
                    <>
                      <BasicVideo autoplay url={`https://www.youtube.com/embed/${promo}?rel=0&enablejsapi`} baseState="paused" displayClass="alt-background paused-background fullscreen-background rounded-bottom" />
                      <hr/>
                    </>
                  )
                }
                <SportPrograms sport={sport} sportName={hyphenated} />
                <div className="d-md-none">
                  <hr/>
                  <SportPoster sportName={hyphenated} />
                </div>
              </div>
            </div>
            <div className='clearfix'></div>
          </div>
        </article>
      </DisplayOrLoading>
    )
  }
}

// export default Background.Decorator(Sport.Decorator(SportPage))
export default Sport.Decorator(SportPage)
