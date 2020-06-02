import React, { Component } from 'react';
import RouteParser from 'common/js/helpers/route-parser'
import { DisplayOrLoading } from 'react-component-templates/components';
import pixelTracker from 'common/js/helpers/pixel-tracker'
import DemoVideo from 'common/js/components/demo-video'

import FindUser, { userIsValid, baseErrorLink } from 'common/js/components/find-user'
import { Sport } from 'common/js/contexts/sport'
import { States } from 'common/js/contexts/states'
// import { Background } from 'common/js/contexts/background'
import PaymentForm from 'common/js/forms/payment-form'
import dusIdFormat from 'common/js/helpers/dus-id-format';

import './payment.css'

const defaultPaymentPageState = { loading: true, type: 0, searchAmount: null, imgWrapperClass: '', description: '', name: '', image: '', }

class PaymentPage extends Component {
  get hydrationParamsKey() {
    try {
      return 'paymentPageComponent-' + this.props.match.params.dusId
    } catch(_) {
      return ''
    }
  }

  constructor(props) {
    super(props)
    try {
      const { match: { params: { dusId = 0 } } } = props,
            dehydrated = window.ssrHydrationParams['paymentPageComponent-' + dusId]

      if(!dusId || !dehydrated) throw new Error("Invalid dusId")


      this.state = {...dehydrated, loading: false}
      console.log(dehydrated, this.state)
    } catch(_) {
      this.state = { ...defaultPaymentPageState }
    }
  }

  componentDidUpdate() {
    if(window.shouldMakeHydrationParamsPublic && this.hydrationParamsKey) {
      window.ssrHydrationParams[this.hydrationParamsKey] = this.state
    }
    // if(this.props.backgroundState.running) {
    //   console.log({ ...this.props.backgroundState })
    //   this.props.backgroundActions.stopLoop()
    //   this.onDescriptionChange({ detail: this.getRouteFromParser() })
    // }
  }

  async componentDidMount(){
    try {
      // this.props.backgroundActions.stopLoop()
      this.onDescriptionChange({ detail: this.getRouteFromParser() })
      window.document.addEventListener('headerLocationChange', this.onDescriptionChange)
      pixelTracker('track', 'PageView')
      const sportLoader = this.props.sportState.loaded ? Promise.resolve() : this.props.sportActions.getSports()
      const statesLoader = this.props.statesState.loaded ? Promise.resolve() : this.props.statesActions.getStates()
      console.log(
        this.props.sportState.loaded,
        this.props.statesState.loaded,
        this.state.loading
      )
      if(
        !this.props.sportState.loaded
        || !this.props.statesState.loaded
        || this.state.loading
      ) {
        return await sportLoader.then(statesLoader).then(this.getUser).then(async (res) => {
          const { match: { params: { dusId = 0 } } } = this.props
          if(!!dusId) {
            switch (Number(this.state.type)) {
              case 2:
                if(/deposit/.test(this.props.location.pathname)) return this.props.history.replace(`/payment/${dusId}${this.props.location.search}`)
                break;
              case 1:
                if(/payment/.test(this.props.location.pathname)) return this.props.history.replace(`/deposit/${dusId}${this.props.location.search}`)
                console.log(this.props)
                break;
              default:
                return this.setState({
                  type: 0,
                  invalid: true,
                  loading: false,
                });
            }

            if(!this.state.description) this.onDescriptionChange({ detail: this.getRouteFromParser() })
          }
        })
      }
    } catch (e) {
      console.error(e)
    }
  }

  componentWillUnmount() {
    // this.props.backgroundActions.startLoop(7500, 0)
    window.document.removeEventListener('headerLocationChange', this.onDescriptionChange)
  }

  getRouteFromParser = () => ({ ...(
    RouteParser.routeCache[this.props.location.pathname.replace(/^\//, '')]
    || RouteParser
  ) })

  onDescriptionChange = (ev) => {
    console.log(ev.detail)
    this.setState({description: (!ev.detail.emptyFetch && ev.detail.description), name: ((ev.detail.result || {}).print_names || ev.detail.id || ev.detail.name), image: ev.detail.image})

    // this.props
    //   .backgroundActions
    //   .setBackground(
    //     ev.detail.image,
    //     { headerClassName: 'd-none' },
    //     { backgroundSize: 'contain', transitionDuration: '.2s' }
    //   )

    try {
      if(/amount=\d+(\.\d{2})?/.test(this.props.location.search)) {
        this.setState({ searchAmount: /amount=(\d+(?:\.\d{2})?)/.exec(this.props.location.search)[1] })
      }
    } catch(err) {
      console.error(err)
    }
  }

  getUser = async () => {
    return new Promise((res) => {
      try {
        const { match: { params: { dusId = 0 } } } = this.props
        if(!dusId) return res(false)

        this.setState({loading: true}, async () => {
          try {
            const type = await userIsValid(dusId)
            this.setState({
              loading: false,
              type,
            }, res)
          } catch(e) {
            console.log(e)
            let link = baseErrorLink.replace('|PAGE_ERROR|', encodeURIComponent(e.toString() || '')).replace('|USER_AGENT|', encodeURIComponent((window.navigator || {}).userAgent))
            try {
              let linkWithHistory = link.replace(/CONSOLE%3A%20.*/, encodeURIComponent('CONSOLE: ' + JSON.stringify(console.history || [])))
              link = linkWithHistory
            } catch (err) {
            }
            if(link && window.confirm(`The following error occured when attempting to find the requested user: ${e.toString()}. Would you like to report this error?`)) {
              window.location.href = link
            } else {
              this.setState({
                type: 0,
                invalid: true,
                error: e.toString(),
                loading: false,
              }, res)
            }

          }
        })
      } catch(e) {
        console.error(e)
        res(e)
      }
    })
  }

  toggleImageClass = (e) => {
    if(!this.state.image) return false
    try {
      if(/close/.test(e.target.className) || /close/.test(e.target.parentElement.className)) {
        this.setState({ imgWrapperClass: 'grow' }, () => {
          setTimeout(() => {
            this.setState({ imgWrapperClass: '' })
          }, 100)
        })
      } else {
        this.setState({ imgWrapperClass: 'grow' }, () => {
          setTimeout(() => {
            this.setState({ imgWrapperClass: 'grow grown' })
          })
        })
      }
    } catch (e) {
      this.setState({ imgWrapperClass: '' })
    }
  }

  render() {
    const { sportState = {}, statesState = {}, match: { params: { dusId } } } = this.props,
          formattedId = dusId && dusIdFormat(dusId)

    return (
      <div className="deposit-page" key={formattedId}>
        <div className="row form-group">
          <div className="col">
            {
              formattedId && this.state.type ? (
                <DisplayOrLoading display={!this.state.loading && (!!sportState.loaded) && (!!statesState.loaded)}>

                  <div className='row'>
                    <div className={`col-12 col-md-4 text-center avatar ${this.state.imgWrapperClass}`}>
                      {
                        this.state.image ? (
                          <div
                            className="img-wrapper"
                            onClick={this.toggleImageClass}
                            data-tooltip={'click to view full size'}
                          >
                            <img
                              className={`img-fluid ${!this.state.imgWrapperClass ? 'clickable' : 'centered'} rounded`}
                              src={this.state.image}
                              alt={this.state.name || 'avatar'}
                            />
                            <button
                              type="button"
                              className="close rounded-circle tooltip-nowrap"
                              aria-label="Close"
                              data-tooltip="Close Fullscreen View"
                            >
                              <span aria-hidden="true">&times;</span>
                            </button>
                            {this.state.image && <i className="material-icons search rounded clickable">search</i>}
                          </div>
                        ) : (
                          <img
                            className="img-fluid"
                            src="/mstile-70x70.png"
                            alt='dus-logo'
                          />
                        )
                      }
                    </div>
                    <div className='col'>
                      {
                        this.state.description ? (
                          <blockquote className="quote-card bg-info">
                            <p>
                              <i>
                                {this.state.description}
                              </i>
                            </p>
                            {
                              this.state.name && (
                                <cite
                                  className={`blockquote-footer text-right ${this.state.image && 'clickable'} tooltip-top-right`}
                                  style={{fontSize: '1.25rem'}}
                                  onClick={this.toggleImageClass}
                                  {...(
                                    this.state.image ? {
                                      'data-tooltip': 'Click to View Avatar'
                                    } : {}
                                  )}
                                >
                                  {this.state.name}
                                </cite>
                              )
                            }
                          </blockquote>

                        ) : (
                          this.state.name && <h3 className="text-center">Make a payment for {this.state.name}</h3>
                        )
                      }
                    </div>
                  </div>
                  <hr/>
                  <PaymentForm id={formattedId} minimum={this.state.type > 1 ? null : 300} defaultAmount={this.state.searchAmount} {...this.props} />
                </DisplayOrLoading>
              ) : (
                <div className="row">
                  <div className="col form-group">
                    <FindUser url='/deposit' travelerUrl='/payment' search={this.props.location.search} />
                  </div>
                </div>
              )
            }
          </div>
        </div>
        <div className="row my-5">
          <div className="col">
            <DemoVideo />
          </div>
        </div>
      </div>
    );
  }
}

// export default Background.Decorator(Sport.Decorator(States.Decorator(PaymentPage)))
export default Sport.Decorator(States.Decorator(PaymentPage))
