import React, { Component } from 'react';
import PropTypes from 'prop-types';
// import { debounce, documentHeight } from 'react-component-templates/helpers';
import { hasTouch, setHoverEvents } from 'common/js/helpers/touch-device';
import ErrorBoundary from 'common/js/components/error-boundary';
import Header from 'common/js/layouts/site/header';
import Footer from 'common/js/layouts/site/footer';
import ChatRedux from 'common/js/components/chat'
// import SiteSeal from 'common/js/components/site-seal'
import './site.css';

const scrollEvents = ['scroll', 'touchmove']

class Site extends Component {
  static propTypes = {
    children: PropTypes.any
  }

  constructor(props){
    super(props)
    this.state = {
      navClass: 'nav-unstuck',
      delay: 10,
      height: 0,
      hoverable: hasTouch() ? '' : 'hoverable',
    }
  }

  componentDidMount(){
    if(hasTouch()) this.bindHover()

    // this.bindScroll()
  }

  componentWillUnmount(){
    this.unbind()
    this.state.removeHover && this.state.removeHover()
  }



  bindHover = () => setHoverEvents(this.onHover, this.onMouse)
    .then((removeHover) => this.setState({removeHover}))

  onHover = () => this.setState({hoverable: ''})

  onMouse = () => this.setState({hoverable: 'hoverable'})

  unbind = () => {
    scrollEvents.map((e) => window.removeEventListener(e, this.state.scrollListener))
  }

  // bindScroll = (delay = 10, unbind = false) => {
  //   unbind && this.unbind()
  //   const scrollListener = debounce(this.handleScroll(), delay)
  //   scrollEvents.map((e) => window.addEventListener(e, scrollListener))
  //   this.setState({scrollListener, delay})
  // }

  // handleScroll = () => {
  //   return () => {
  //     const height = (this.state.height || (documentHeight() / 4))
  //     if((this.state.navClass === 'nav-unstuck') && (window.scrollY > height)) this.setState({navClass: 'nav-stuck'})
  //     else if((this.state.navClass === 'nav-stuck') && (window.scrollY < (height + 1))) this.setState({navClass: 'nav-unstuck'})
  //
  //     if((this.state.delay < 400) && (window.scrollY > (height * 4))) this.bindScroll(400, true)
  //     else if((this.state.delay > 200) && (window.scrollY < ((height * 4) + 1))) this.bindScroll(200, true)
  //     else if((this.state.delay < 200) && (window.scrollY > (height * 2))) this.bindScroll(200, true)
  //     else if((this.state.delay > 10) && (window.scrollY < ((height * 2) + 1))) this.bindScroll(10, true)
  //   }
  // }

  render() {
    return (
      <section key="main-wrapper" id="dus-site-outer-wrapper" className={`Site ${this.state.hoverable}`}>
        <ErrorBoundary key="header-boundary">
          {/*<Header key="site-header" navClass={this.state.navClass} heightRef={(height) => this.setState({height}, this.bindScroll)}/>*/}
          <Header key="site-header" navClass={this.state.navClass} heightRef={(height) => this.setState({ height })}/>
        </ErrorBoundary>
        <div key="special-offer" className="container-fluid mt-3" style={{maxWidth: '1140px'}}>
          <div className="Site-special-offer">
            <div className="ribbon-wrapper">
              <h3 className="ribbon">
                <strong className="ribbon-inner">
                  Thank You For Your Patience
                </strong>
              </h3>
            </div>
            <hr className="d-block w-100"/>
            <p className="text-dark">
              Our office will have limited availability throughout the month of April while our communities address COVID-19. If you are unable to reach us, please leave a message or send us an email and we will get back to you as soon as we are able. We appreciate your understanding.<span className="footnote-notice">**</span>
            </p>
            <div className="footnote">
              **We are in the process of contacting <strong>all</strong> of our 2020 participants. If you are currently signed up for our 2020 program, you do not need to contact us first.
            </div>
          </div>
        </div>
        <ErrorBoundary key="content-boundary">
          <div key="main-content" className="main Site-main container">
            {this.props.children}
          </div>
        </ErrorBoundary>
        <div key="main-content-clearfix" id="main-content-clearfix" className='clearfix'></div>
        {/*
        <ErrorBoundary key="seal-boundary">
          <SiteSeal className="main-site-seal" key="site-seal" />
        </ErrorBoundary>
        */}
        <ErrorBoundary key="chat-boundary">
          <ChatRedux key="chat-component" />
        </ErrorBoundary>
        <ErrorBoundary key="footer-boundary">
          <Footer key="site-footer" />
        </ErrorBoundary>
      </section>
    );
  }
}

export default Site;
