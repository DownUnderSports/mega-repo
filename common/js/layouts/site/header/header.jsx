import React, { Component } from 'react'
import { node, string, object } from 'prop-types';
import { withRouter } from 'react-router-dom';

import { Background } from 'common/js/contexts/background'
import { ConnectionSpeed, Menu } from 'react-component-templates/contexts';
import { debounce, Objected } from 'react-component-templates/helpers';

import { HeaderLinks, HeaderLogo } from './components'
import ResponseVideo from 'common/js/components/response-video'

import checkVersion from 'common/js/helpers/check-version'
import RouteParser from 'common/js/helpers/route-parser'

import './header.css';

const resizeEvents = ['orientationchange', 'resize']
const locationChangeEvent = (state) => {
  window.document.dispatchEvent(new CustomEvent(
    'headerLocationChange',
    {
      detail: Objected.deepClone(state),
      bubbles: true,
      cancelable: false,
    }
  ))
}

const imageIdxArray = new Array(5).fill(0).map((v, i) => i)

const links = [
  {
    to: "/",
    children: 'Home',
  },
  {
    to: "/payment",
    children: 'Donate',
  },
  [
    'About Us',
    {
      to: '/',
      children: 'Our Story'
    },
    // {
    //   to: '/frequently-asked-questions',
    //   children: 'F.A.Q.'
    // },
    // {
    //   to: '/our-staff',
    //   children: 'Meet Our Staff'
    // },
    {
      to: '/contact',
      children: 'Contact Us'
    },
  ],
  [
    'Join the Team',
    {
      to: "/infokit",
      children: 'Request Info',
    },
    {
      to: "/deposit",
      children: 'Sign Up',
    },
    {
      to: "/open-tryouts",
      children: 'Open Tryouts',
    },
    {
      to: "/nomination-form",
      children: 'Nominate Athletes',
    },
  ],
  // [
  //   "Sports",
  //   {
  //     to: "/sports/BBB",
  //     children: 'Boys Basketball',
  //   },
  //   {
  //     to: "/sports/GBB",
  //     children: 'Girls Basketball',
  //   },
  //   {
  //     to: "/sports/XC",
  //     children: 'Cross Country',
  //   },
  //   {
  //     to: "/sports/FB",
  //     children: 'Football',
  //   },
  //   {
  //     to: "/sports/GF",
  //     children: 'Golf',
  //   },
  //   {
  //     to: "/sports/TF",
  //     children: 'Track & Field',
  //   },
  //   {
  //     to: "/sports/VB",
  //     children: 'Volleyball',
  //   },
  // ],
  [
    'Program History',
    {
      to: "/participants",
      children: 'Past Participants',
    },
    {
      to: "https://downundersports.smugmug.com",
      children: 'Photo Galleries',
    },
  ],
  // [
  //   "Legal",
  //   {
  //     to: "/terms",
  //     children: 'Terms & Conditions',
  //   },
  //   {
  //     to: "/refunds",
  //     children: 'Refund Policy',
  //   },
  //   {
  //     to: "/privacy-policy",
  //     children: 'Privacy Policy',
  //   },
  // ],
]

class Header extends Component {
  static propTypes = {
    title: node,
    navClass: string,
    history: object
  }

  constructor(props) {
    super(props)
    this.state = {
      top: 0,
      connectionSpeed: Header.calcSpeed(props)
    }
    props.history.listen(this.getTitle)
  }

  static calcSpeed(props) {
    return (!!props.connectionSpeedState && props.connectionSpeedState.effectiveType) || '4g'
  }

  static getDerivedStateFromProps(nextProps, prevState) {
    const connectionSpeed = Header.calcSpeed(nextProps)

    return (connectionSpeed !== prevState.connectionSpeed) ? { connectionSpeed } : null
  }

  componentDidMount(){
    this.bindResize()
    RouteParser.setPath(this.props.location)
    .then((result) => this.setState({...result}))
  }

  componentDidUpdate(oldProps, oldState){
    if((oldState.title !== this.state.title) || (oldState.description !== this.state.description) || (oldState.id !== this.state.id)) locationChangeEvent(this.state)
  }

  getTitle = async (location, action) => {
    checkVersion()
    this.setState({...await RouteParser.setPath(location)})
    setTimeout(this.handleResize)
  }

  componentWillUnmount(){
    this.unbind()
  }

  handleResize = () => {
    const h = ((this.headerEl && this.headerEl.clientHeight) || 0) - ((this.navEl && this.navEl.clientHeight) || 0)
    this.props.heightRef && this.props.heightRef(h)
    this.setState({top: `-${h}px`})
    this.props.menuActions && this.props.menuActions.closeMenu()
  }

  unbind = () => {
    resizeEvents.map((e) => window.removeEventListener(e, this.state.resizeListener))
  }

  bindResize = () => {
    this.handleResize()
    const resizeListener = debounce(this.handleResize, 50)
    resizeEvents.map((e) => window.addEventListener(e, resizeListener))
    this.setState({resizeListener})
  }

  getTitleObject = () => {
    const {
      title,
      description,
      image,
      currentRoute = {
        description_properties: {
          view_props: {}
        },
        title_properties: {
          view_props: {}
        },
        image_properties: {
          view_props: {}
        }
      }
    } = this.state || {},
    {
      description_properties: descriptionProperties = {},
      image_properties: imageProperties = {},
      title_properties: titleProperties = {}
    } = currentRoute,
    {
      display_in_header: displayDescription = false,
      view_props: descriptionViewProps = {
        className: 'font-weight-bold font-italic'
      }
    } = (descriptionProperties || {}),
    {
      display_in_header: displayImage = false,
      view_props: imageViewProps = {}
    } = (imageProperties || {}),
    {
      display_logo: displayLogo = true,
      display_in_header: displayTitle = true,
      view_props: titleViewProps = {
        className: 'font-weight-bolder'
      }
    } = (titleProperties || {})
    return {
      displayLogo: !!(displayLogo),
      displayTitle: !!(displayTitle),
      title: title || '',
      titleViewProps: titleViewProps || {},
      description: description || '',
      displayDescription: !!(displayDescription && description),
      descriptionViewProps: descriptionViewProps || {},
      displayImage: !!(displayImage && image),
      imageViewProps: imageViewProps || {},
    }
  }

  previousBackground = () => this.props.backgroundActions.previousBackground()
  nextBackground = () => this.props.backgroundActions.nextBackground()

  isCurrentIdx(idx, imgIdx) {
    if(imgIdx < 1) return idx === imageIdxArray.length - 1
    return imgIdx - 1 === idx
  }

  render(){
    const {
      title,
      displayLogo,
      displayTitle,
      // titleViewProps,
      description,
      displayDescription,
      descriptionViewProps,
    } = this.getTitleObject()

    const {
      imageSrc = '',
      headerClassName = '',
      currentImage = {},
      running = false,
      // imgIdx = 1,
    } = this.props.backgroundState || {}

    const { location  = {} } = this.props,
          { pathname = '' } = location || {}

    return (
      <header
        key="header"
        ref={(el) => this.headerEl = el}
        className="Site-header"
        style={{ top: this.state.top || 0 }}
      >
        <div
          ref={(el) => this.navEl = el}
          className={`nav-wrapper ${this.props.navClass}`}
         >
          <HeaderLogo />
          <HeaderLinks path={pathname} links={links} />
        </div>
        <div className="social-bar">
          <a
            href="https://facebook.com/DownUnderSports"
            target="_facebook"
            rel="noopener"
            aria-label="Facebook"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="navbar-nav-svg"
              viewBox="0 0 310 310"
              role="img"
              focusable="false"
            >
              <path
                fill="currentColor"
                d="M81.703,165.106h33.981V305c0,2.762,2.238,5,5,5h57.616c2.762,0,5-2.238,5-5V165.765h39.064   c2.54,0,4.677-1.906,4.967-4.429l5.933-51.502c0.163-1.417-0.286-2.836-1.234-3.899c-0.949-1.064-2.307-1.673-3.732-1.673h-44.996   V71.978c0-9.732,5.24-14.667,15.576-14.667c1.473,0,29.42,0,29.42,0c2.762,0,5-2.239,5-5V5.037c0-2.762-2.238-5-5-5h-40.545   C187.467,0.023,186.832,0,185.896,0c-7.035,0-31.488,1.381-50.804,19.151c-21.402,19.692-18.427,43.27-17.716,47.358v37.752H81.703   c-2.762,0-5,2.238-5,5v50.844C76.703,162.867,78.941,165.106,81.703,165.106z"
              />
            </svg>
          </a>
          <a
            href="https://instagram.com/DownUnderSports"
            target="_instagram"
            rel="noopener"
            aria-label="Instagram"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="navbar-nav-svg"
              viewBox="0 0 512 512"
              role="img"
              focusable="false"
            >
            	<path
                fill="currentColor"
                d="M256,49.471c67.266,0,75.233.257,101.8,1.469,24.562,1.121,37.9,5.224,46.778,8.674a78.052,78.052,0,0,1,28.966,18.845,78.052,78.052,0,0,1,18.845,28.966c3.45,8.877,7.554,22.216,8.674,46.778,1.212,26.565,1.469,34.532,1.469,101.8s-0.257,75.233-1.469,101.8c-1.121,24.562-5.225,37.9-8.674,46.778a83.427,83.427,0,0,1-47.811,47.811c-8.877,3.45-22.216,7.554-46.778,8.674-26.56,1.212-34.527,1.469-101.8,1.469s-75.237-.257-101.8-1.469c-24.562-1.121-37.9-5.225-46.778-8.674a78.051,78.051,0,0,1-28.966-18.845,78.053,78.053,0,0,1-18.845-28.966c-3.45-8.877-7.554-22.216-8.674-46.778-1.212-26.564-1.469-34.532-1.469-101.8s0.257-75.233,1.469-101.8c1.121-24.562,5.224-37.9,8.674-46.778A78.052,78.052,0,0,1,78.458,78.458a78.053,78.053,0,0,1,28.966-18.845c8.877-3.45,22.216-7.554,46.778-8.674,26.565-1.212,34.532-1.469,101.8-1.469m0-45.391c-68.418,0-77,.29-103.866,1.516-26.815,1.224-45.127,5.482-61.151,11.71a123.488,123.488,0,0,0-44.62,29.057A123.488,123.488,0,0,0,17.3,90.982C11.077,107.007,6.819,125.319,5.6,152.134,4.369,179,4.079,187.582,4.079,256S4.369,333,5.6,359.866c1.224,26.815,5.482,45.127,11.71,61.151a123.489,123.489,0,0,0,29.057,44.62,123.486,123.486,0,0,0,44.62,29.057c16.025,6.228,34.337,10.486,61.151,11.71,26.87,1.226,35.449,1.516,103.866,1.516s77-.29,103.866-1.516c26.815-1.224,45.127-5.482,61.151-11.71a128.817,128.817,0,0,0,73.677-73.677c6.228-16.025,10.486-34.337,11.71-61.151,1.226-26.87,1.516-35.449,1.516-103.866s-0.29-77-1.516-103.866c-1.224-26.815-5.482-45.127-11.71-61.151a123.486,123.486,0,0,0-29.057-44.62A123.487,123.487,0,0,0,421.018,17.3C404.993,11.077,386.681,6.819,359.866,5.6,333,4.369,324.418,4.079,256,4.079h0Z"
              />
            	<path
                fill="currentColor"
                d="M256,126.635A129.365,129.365,0,1,0,385.365,256,129.365,129.365,0,0,0,256,126.635Zm0,213.338A83.973,83.973,0,1,1,339.974,256,83.974,83.974,0,0,1,256,339.973Z"
              />
            	<circle
                fill="currentColor"
                cx="390.476"
                cy="121.524"
                r="30.23"
              />
            </svg>
          </a>
          <a
            href="https://twitter.com/DownUnderSports"
            target="_twitter"
            rel="noopener"
            aria-label="Twitter"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="navbar-nav-svg"
              viewBox="0 0 512 416.32"
              role="img"
              focusable="false"
            >
              <title>Twitter</title>
              <path
                fill="currentColor"
                d="M160.83 416.32c193.2 0 298.92-160.22 298.92-298.92 0-4.51 0-9-.2-13.52A214 214 0 0 0 512 49.38a212.93 212.93 0 0 1-60.44 16.6 105.7 105.7 0 0 0 46.3-58.19 209 209 0 0 1-66.79 25.37 105.09 105.09 0 0 0-181.73 71.91 116.12 116.12 0 0 0 2.66 24c-87.28-4.3-164.73-46.3-216.56-109.82A105.48 105.48 0 0 0 68 159.6a106.27 106.27 0 0 1-47.53-13.11v1.43a105.28 105.28 0 0 0 84.21 103.06 105.67 105.67 0 0 1-47.33 1.84 105.06 105.06 0 0 0 98.14 72.94A210.72 210.72 0 0 1 25 370.84a202.17 202.17 0 0 1-25-1.43 298.85 298.85 0 0 0 160.83 46.92"
              />
            </svg>
          </a>
        </div>
        <div id="site-banner" className="banner-video">
          <div className="outer-wrapper">
            <div className="outer-content">
              <div className="message">
                <div className="ribbon-wrapper">
                  <h3 className="ribbon">
                    <strong className="ribbon-inner">
                      A message from Down Under Sports
                    </strong>
                  </h3>
                </div>
              </div>
              <div className="video-container">
                <ResponseVideo
                  displayClass="alt-background paused-background keep-aspect fullscreen-background"
                />
              </div>
            </div>
          </div>
        </div>
        {
          !!imageSrc
          && false
          && (
            <div
              className={`carousel ${headerClassName}`}
              style={{...currentImage}}
              id="site-carousel"
            >
              { displayLogo && <HeaderLogo className="top-logo" /> }


              {/*
              <div className="carousel-inner">
                <div className="carousel-item active" >
                  <img src={imageSrc} className="d-block" alt="Header Image"/>
                </div>
              </div>
              */}
              {
                running && (
                  <>
                    {
                      /*
                      <ol key="indicators" className="carousel-indicators">
                        {
                          imageIdxArray.map((idx) => (
                            <li
                              key={idx}
                              className={this.isCurrentIdx(idx, imgIdx) ? 'active' : ''}
                            />
                          ))
                        }
                      </ol>
                      */
                    }
                    <button
                      key="prev"
                      className="carousel-control-prev"
                      type="button"
                      data-slide="prev"
                      onClick={this.previousBackground}
                      data-tooltip="Previous Slide"
                    >
                      <span className="carousel-control-prev-icon" aria-hidden="true"></span>
                      <span className="sr-only">Previous Slide</span>
                    </button>
                    <button
                      key="next"
                      className="carousel-control-next"
                      type="button"
                      data-slide="next"
                      onClick={this.nextBackground}
                      data-tooltip="Next Slide"
                    >
                      <span className="carousel-control-next-icon" aria-hidden="true"></span>
                      <span className="sr-only">Next Slide</span>
                    </button>
                  </>
                )
              }
            </div>
          )

        }
        <div id="site-header-content" className="header-content">
          <h1 className="Site-title">
            {
              displayTitle && (
                <span>
                  {title || (<span>Down Under Sports</span>)}
                </span>
              )
            }
            {
              /*
              displayTitle && (
                <span
                  {...titleViewProps}
                >
                  {title || (<span>Down Under Sports</span>)}
                </span>
              )
              */
            }
          </h1>
          <h3 className="Site-subtitle">
            {
              displayDescription && (
                <span
                  {...descriptionViewProps}
                >
                  {description}
                </span>
              )
            }
          </h3>
        </div>
      </header>
    )
  }
}

export default ConnectionSpeed.Decorator(
  Background.Decorator(
    Menu.Decorator(
      withRouter(Header)
    )
  )
)
