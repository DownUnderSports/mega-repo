import React from 'react';
import Component from 'common/js/components/component'
import FindUser from 'common/js/components/find-user'
import { Background } from 'common/js/contexts/background'

import { DisplayOrLoading, Link } from 'react-component-templates/components';
// import { TextField } from 'react-component-templates/form-components';
import YouTubePlayer from 'react-player/lib/players/YouTube'
//import authFetch from 'common/js/helpers/auth-fetch'
import throttle from 'common/js/helpers/throttle'
import dateFns from 'date-fns'

// import backgroundSVG from 'common/assets/images/background.svg'

const categories = {
  i: 'Information',
  f: 'Fundraising',
  d: 'Departure',
  s: 'Staff',
  a: 'Athlete',
  p: 'Parent/Guardian',
}

// const pad = function (string) {
  //   return ('0' + string).slice(-2)
// }

// const format = function (seconds) {
//   const date = new Date(seconds * 1000)
//   const hh = date.getUTCHours()
//   const mm = date.getUTCMinutes()
//   const ss = pad(date.getUTCSeconds())
//   return `${pad(hh)}:${pad(mm)}:${ss}`
// }


// const Duration = ({ className, seconds }) => (
//   <time dateTime={`P${Math.round(seconds)}S`} className={className}>
//     {format(seconds)}
//   </time>
// )


class VideoPlayer extends Component {
  static contextType = Background.Context

  state = {
    loading: false,
    url: null,
    pip: false,
    playing: false,
    volume: 0.8,
    muted: false,
    played: 0,
    loaded: 0,
    duration: 0,
    playbackRate: 1.0,
    loop: false,
    maxProgress: 0,
    maxProgressSeconds: 0,
    watched: false,
    deadline: '',
    twoWeeks: '',
    traveler: false
  }

  async componentDidMount(){
    if(!this.props.autoplay) this.context.backgroundActions.stopLoop()

    this.trackUser = throttle(this.trackUser, 5000, true)
    if(this.props.asyncUrl) {
      await this.setStateAsync({loading: true})
      try {
        const result =  await fetch(this.props.asyncUrl),
              json = await result.json()
        await this.setStateAsync({
          playing: this.state.playing || !!this.props.autoplay,
          loading: false,
          url: json.url,
          played: 0,
          loaded: 0,
          trackingUrl: json.tracking_url || this.props.trackingUrl,
          hasTracking: !!json.tracking_url || json.has_tracking,
          hasOffers: !!json.has_offers,
        })
      } catch(e) {
        await this.setStateAsync({loading: false})
      }
    } else {
      await this.setStateAsync({
        playing: this.state.playing || !!this.props.autoplay
      })
    }
  }

  componentWillUnmount(){
    if(!this.props.autoplay) this.context.backgroundActions.startLoop(7500, 0)
  }

  playPause = () => {
    this.setState({ playing: !this.state.playing })
  }
  pip = () => {
    this.setState({ pip: !this.state.pip })
  }
  stop = () => {
    this.setState({ url: null, playing: false })
  }
  toggleLoop = () => {
    this.setState({ loop: !this.state.loop })
  }
  setVolume = e => {
    this.setState({ volume: parseFloat(e.target.value) })
  }
  toggleMuted = () => {
    this.setState({ muted: !this.state.muted })
  }
  setPlaybackRate = e => {
    this.setState({ playbackRate: parseFloat(e.target.value) })
  }
  onPlay = () => {
    console.log('onPlay')
    this.setState({ playing: true })
  }
  onPause = () => {
    console.log('onPause')
    this.setState({ playing: false })
  }
  onSeekMouseDown = e => {
    this.setState({ seeking: true })
  }
  onSeekChange = e => {
    this.setState({ played: parseFloat(e.target.value) })
  }
  onSeekMouseUp = e => {
    this.setState({ seeking: false })
    this.seekTo(e.target.value)
  }
  onProgress = state => {
    console.log('onProgress', state)
    // We only want to update time slider if we are not currently seeking
    if (!this.state.seeking) {
      if(state.playedSeconds > (this.state.maxProgressSeconds + 10)) {
        return this.seekTo(this.state.maxProgress)
      }

      this.setState({...state, maxProgress: Math.max(state.played, this.state.maxProgress), maxProgressSeconds: Math.max(state.playedSeconds, this.state.maxProgressSeconds)}, this.trackUser)
    }
  }
  onEnded = () => {
    console.log('onEnded')
    this.props.onEnded ? this.props.onEnded(this) : this.setState({ playing: this.state.loop })
  }
  onDuration = (duration) => {
    console.log('onDuration', duration)
    this.setState({ duration })
  }

  seekTo = (value) => {
    this.player.seekTo(parseFloat(value))
  }

  trackUser = async () => {
    try {
      if(this.state.hasTracking) {
        const { trackingId = this.props.trackingId, trackingUrl = this.props.trackingUrl } = this.state
        if(trackingId) {
          const underscored = {}
          for(let k in this.state) {
            underscored[`${k}`.replace(/[a-z][A-Z]/g, (a) => a.split('').join('_')).toLowerCase()] = this.state[k]
          }
          underscored.tracking_id = trackingId
          const result = await fetch(trackingUrl.replace(/:[A-Za-z_]+/, trackingId), {
            method: 'POST',
            headers: {
              "Content-Type": "application/json; charset=utf-8"
            },
            body: JSON.stringify(underscored)
          }),
          { max_watched: maxWatched = 0, watched = false, deadline: unformattedDeadline = '', two_weeks: unformattedTwoWeeks = '', traveler = false } = await result.json()

          let deadline = '', twoWeeks = ''

          if(unformattedDeadline) {
            try {
              // deadline = dateFns.format(dateFns.parse(unformattedDeadline), 'dddd, MMMM Do, YYYY') || ''
              deadline = dateFns.format(dateFns.parse(unformattedDeadline), 'MMMM Do') || ''
            } catch(_) {
              deadline = ''
            }
          }

          if(unformattedTwoWeeks) {
            try {
              twoWeeks = dateFns.format(dateFns.parse(unformattedTwoWeeks), 'dddd, MMMM Do, YYYY') || ''
            } catch(_) {
              twoWeeks = ''
            }
          }

          console.log(maxWatched)

          if(maxWatched && (parseFloat(maxWatched) > this.state.maxProgressSeconds)) {
            console.log({
              maxProgress: parseFloat(maxWatched) / this.state.duration,
              maxProgressSeconds: parseInt(maxWatched),
              watched: !!watched,
              deadline,
              twoWeeks,
              traveler,
            })
            this.setState({
              maxProgress: parseFloat(maxWatched) / this.state.duration,
              maxProgressSeconds: parseInt(maxWatched),
              watched: !!watched,
              deadline,
              twoWeeks,
              traveler,
            })
          } else if (watched) {
            this.setState({ watched: true, deadline, twoWeeks, traveler })
          }
        }
      }
    } catch(e) {
      console.error(e)
    }

  }

  scheduleAppt = (ev) => {
    ev.preventDefault()
    this.setState({ playing: false })
    // const trackingId = this.state.trackingId || this.props.trackingId || ''
    // return 'mailto:mail@downundersports.com'
    //         + '?subject=Schedule%20an%20Appointment'
    //         + '&body=I%20would%20like%20to%20request%20a%20scheduled%20appointment%0D%0A%0D%0A'
    //         + 'My Name:%20%0D%0A'
    //         + (trackingId ? `Athlete%20DUS%20ID:%20${trackingId}%0D%0A` : 'Athlete Name:%20%0D%0A')
    //         + 'Date:%20%0D%0A'
    //         + 'Time%20(with%20timezone):%20'
    //         + '%0D%0A%0D%0AI%20am%20curious%20about:%20'
    return window.open('https://www.meetingbird.com/l/DownUnderSports/one-on-one','_schedule_appt','noopener noreferrer')
  }

  get reserveSpot() {
    const trackingId = this.state.trackingId || this.props.trackingId || ''
    return 'mailto:mail@downundersports.com'
            + '?subject=Reserve%20My%20Spot%20for%202021'
            + '&body=I%20would%20like%20to%20reserve%20a%20spot%20in%20the%202021%20competitions%0D%0A%0D%0A'
            + 'My Name:%20%0D%0A'
            + (trackingId ? `Athlete%20DUS%20ID:%20${trackingId}%0D%0A` : 'Athlete Name:%20%0D%0A')
  }

  // onClickFullscreen = () => {
  //   screenfull.request(findDOMNode(this.player))
  // }

  ref = player => this.player = player

  render() {
    const {
      loading = false,
      url = this.props.url,
      hasTracking = false,
      hasOffers = false,
      trackingId = this.props.trackingId || '',
      // played,
      playing,
      // duration
      // watched = false,
      // deadline = '',
      // twoWeeks = '',
      // traveler = false,
    } = this.state

    return (
      <DisplayOrLoading display={!loading} >
        {
          url ? (
            <div className='row'>
              <div className='col'>
                {
                  hasTracking && hasOffers && (
                    trackingId ? (
                      <div className="alert alert-warning" role="alert">
                        <h4 className="alert-heading text-center">Eligibility Notice!</h4>
                        <p>
                          In order to be eligible for any discounts offered in the video below, you <strong>must</strong> stay on this page while watching the video.
                        </p>
                      </div>
                    ) : (
                      <div className='row'>
                        <div className='col'>
                          <div className="alert alert-warning text-center" role="alert">
                            Enter Your DUS ID in the box below to be eligible for any discounts or promotions offered
                          </div>
                          <FindUser skipExtras skipHelper url={window.location.pathname} />
                        </div>
                      </div>
                    )
                  )
                }
                <div className="responsive-video mb-3">
                  <YouTubePlayer
                    controls
                    ref={this.ref}
                    className='video-player'
                    url={this.props.url || this.state.url}
                    width='100%'
                    height='100%'
                    config={{
                      modestbranding: 1,
                      start: 0,
                    }}
                    onStart={this.onStart}
                    onPlay={this.onPlay}
                    onPause={this.onPause}
                    onProgress={this.onProgress}
                    onDuration={this.onDuration}
                    onBuffer={this.onBuffer}
                    onSeek={this.onSeek}
                    onEnded={this.onEnded}
                    onError={this.onError}
                    progressInterval={500}
                    playing={playing}
                  />
                </div>
                {
                  // <div className='row form-group'>
                  //   <div className="col">
                  //     <TextField
                  //       label="Seek"
                  //       type='range' min={0} max={1} step='any'
                  //       className='form-control-range'
                  //       value={played}
                  //       onMouseDown={this.onSeekMouseDown}
                  //       onChange={this.onSeekChange}
                  //       onMouseUp={this.onSeekMouseUp}
                  //     />
                  //   </div>
                  // </div>
                  // <div className='row form-group'>
                  //   <div className="col">
                  //     <table className='table'>
                  //       <tbody>
                  //         <tr>
                  //           <th>duration</th>
                  //           <td><Duration seconds={duration} /></td>
                  //         </tr>
                  //         <tr>
                  //           <th>elapsed</th>
                  //           <td><Duration seconds={duration * played} /></td>
                  //         </tr>
                  //         <tr>
                  //           <th>remaining</th>
                  //           <td><Duration seconds={duration * (1 - played)} /></td>
                  //         </tr>
                  //       </tbody>
                  //     </table>
                  //   </div>
                  // </div>
                }
                {
                  this.props.showSignup ? (
                    // traveler ? (
                    false ? (
                      <div className='row'>
                        <div className="col-12 form-group">
                          <div className="card">
                            <div className="card-body">
                              <h3 className="card-title text-center text-success">You've Already Joined the Team!</h3>
                              <div className="row">
                                <div className="col-auto">
                                  <Link className='btn btn-info btn-lg' to="https://drive.google.com/file/d/1b5dMilMB5k4NE7JJiuGaeNSpZuqvh23M/view?usp=sharing" target='_info_program'>
                                    2019 Program
                                  </Link>
                                </div>
                                <div className="col">
                                  <Link className='btn btn-success btn-lg btn-block' to={`/payment/${trackingId}`}>Click Here to Make a Payment</Link>
                                </div>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    ) : (
                      <div className='row'>
                        <div className="col-12 form-group">
                          <div className="card">
                            <div className="card-body">
                              <h3 className="card-title text-center text-success">Register for 2021!</h3>
                              <ul>
                                <li>
                                  2021 Registrations will begin May 1st.
                                </li>
                                <li>
                                  Reserve your spot today and one of our recruiters will follow up with you!
                                </li>
                              </ul>
                            </div>
                          </div>
                        </div>
                        {
                          /*
                          !!watched && (
                            <div className="col-12 form-group">
                              <div className="card">
                                <div className="card-body">
                                  <h3 className="card-title text-center text-success">Unlocked Discount!</h3>
                                  <ul>
                                    <li>
                                      Take a leap this year to get your fundraising packet for only $29 if you sign up by April 1<sup>st</sup>!
                                    </li>
                                    <li>
                                      Fundraise or pay the rest of your $300 deposit by April 12<sup>th</sup> to get a $777 discount!
                                    </li>
                                  </ul>
                                </div>
                              </div>
                            </div>
                          )
                          */
                          /*
                          !!watched && (
                            <div className="col-12 form-group">
                              <div className="card">
                                <div className="card-body">
                                  <h3 className="card-title text-center text-success">Unlocked Discount!</h3>
                                  <ul>
                                    <li>
                                      Join the team at anytime within the next two weeks to unlock discount opportunities of up to $500!
                                    </li>
                                    <li>
                                      Join the team { deadline ? <>by <strong>{deadline}</strong></> : 'within 72 hours (3 days from first watch date)' } and you will get an automatic $200 discount, plus unlock the regular $500 discount opportunities.
                                    </li>
                                  </ul>
                                </div>
                              </div>
                            </div>
                          )
                          */
                        }
                        <div className="col-auto">
                          <Link className='btn btn-info btn-lg' to="https://drive.google.com/file/d/1ynXn4-yJiAORz3PweFB9ZpDhk3RoN-ti/view?usp=sharing" target='_info_flyer'>
                            Price
                          </Link>
                        </div>
                        <div className="col-auto">
                          <Link className='btn btn-secondary btn-lg' to="https://drive.google.com/file/d/1b5dMilMB5k4NE7JJiuGaeNSpZuqvh23M/view?usp=sharing" target='_info_program'>
                            2019 Program
                          </Link>
                        </div>
                        <div className="col-auto">
                          <Link className='btn btn-primary btn-lg' to={`/frequently-asked-questions?dus_id=${trackingId}`}>
                            F.A.Q.
                          </Link>
                        </div>
                        <div className='col'>
                          <Link
                            className='btn btn-success btn-lg btn-block'
                            to={this.reserveSpot}
                          >
                            Reserve Your Spot!
                          </Link>
                        </div>
                        <div className="col-12 my-3">
                          <hr/>
                          <Link
                            className='btn btn-secondary float-right'
                            to="https://www.meetingbird.com/l/DownUnderSports/one-on-one"
                            onClick={this.scheduleAppt}
                          >
                            Schedule a One-on-One Appointment
                          </Link>
                        </div>
                      </div>
                    )
                  ) : (
                    !!this.props.showFAQ && (
                      <div className='row'>
                        <div className="col-12 form-group">
                          <div className="card">
                            <div className="card-body">
                              <h3 className="card-title text-center text-success">Register for 2021!</h3>
                              <ul>
                                <li>
                                  2021 Registrations will begin May 1st.
                                </li>
                                <li>
                                  Reserve your spot today and one of our recruiters will follow up with you!
                                </li>
                              </ul>
                            </div>
                          </div>
                        </div>
                        <div className="col-auto">
                          <Link className='btn btn-primary btn-lg' to={`/frequently-asked-questions${trackingId ? `?dus_id=${trackingId}` : ''}`}>
                            F.A.Q.
                          </Link>
                        </div>
                        <div className='col'>
                          <Link
                            className='btn btn-success btn-lg btn-block'
                            to={this.reserveSpot}
                          >
                            Reserve Your Spot!
                          </Link>
                        </div>
                        <div className="col-12 my-3">
                          <hr/>
                          <Link
                            className='btn btn-secondary float-right'
                            to="https://www.meetingbird.com/l/DownUnderSports/one-on-one"
                            onClick={this.scheduleAppt}
                          >
                            Schedule a One-on-One Appointment
                          </Link>
                        </div>
                      </div>
                    )
                  )
                }
              </div>
            </div>
          ) : (
            <div className="alert alert-warning" role="alert">
              <h4 className="alert-heading text-center">Uh Oh!</h4>
              <p>The Video Requested Could Not Be Found</p>
              <hr />
              <p className="mb-0">
                Please contact our office by <a href="tel:+1-435-753-4732">calling us @ 435-753-4732</a> or sending an email to <a href="mailto:mail@downundersports.com">mail@downundersports.com</a>
              </p>
            </div>
          )
        }
      </DisplayOrLoading>

    )
  }
}

export default class VideosPage extends Component {
  render() {
    const { match: { params: { category = 'i', userId } } } = this.props,
          formatted = `${category}`.toLowerCase()[0],
          categoryTitle = categories[formatted],
          fetchUrl = `/api/videos/${categoryTitle ? formatted : 'i'}`

    return (
      <section className='VideosPage my-4'>
        <header className='mb-4'>
          <h3>
            View { categoryTitle || categories.i } Video
          </h3>
        </header>
        <div className="main">
          <div className='clearfix'></div>
          <VideoPlayer
            trackingId={userId}
            asyncUrl={fetchUrl}
            trackingUrl={`${fetchUrl}/:trackingId`}
            showSignup={!!userId && (formatted === 'i')}
            showFAQ={/f|i/.test(formatted)}
          />
          <div className='clearfix'></div>
        </div>
      </section>
    );
  }
}
