import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { debounce, documentHeight } from 'react-component-templates/helpers';
import Header from 'layouts/admin/admin-header';
import Footer from 'layouts/admin/admin-footer';
import Authenticated from 'components/authenticated';
import './admin.css';

const scrollEvents = ['scroll', 'touchmove']

class Admin extends Component {
  static propTypes = {
    children: PropTypes.any
  }

  constructor(props){
    super(props)
    this.state = {
      navClass: 'nav-unstuck',
      delay: 10,
      height: 0
    }
  }

  componentDidMount(){
    this.bindScroll()
  }

  componentWillUnmount(){
    this.unbind()
  }

  unbind = () => {
    scrollEvents.map((e) => window.removeEventListener(e, this.state.scrollListener))
  }

  bindScroll = (delay = 10, unbind = false) => {
    unbind && this.unbind()
    const scrollListener = debounce(this.handleScroll(), delay)
    scrollEvents.map((e) => window.addEventListener(e, scrollListener))
    this.setState({scrollListener, delay})
  }

  handleScroll = () => {
    return () => {
      const height = (this.state.height || (documentHeight() / 4))
      if((this.state.navClass === 'nav-unstuck') && (window.scrollY > height)) this.setState({navClass: 'nav-stuck'})
      else if((this.state.navClass === 'nav-stuck') && (window.scrollY < (height + 1))) this.setState({navClass: 'nav-unstuck'})

      if((this.state.delay < 400) && (window.scrollY > (height * 4))) this.bindScroll(400, true)
      else if((this.state.delay > 200) && (window.scrollY < ((height * 4) + 1))) this.bindScroll(200, true)
      else if((this.state.delay < 200) && (window.scrollY > (height * 2))) this.bindScroll(200, true)
      else if((this.state.delay > 10) && (window.scrollY < ((height * 2) + 1))) this.bindScroll(10, true)
    }
  }

  render() {
    return (
      <Authenticated>
        <section id="dus-site-outer-wrapper" className="Admin">
          <Header navClass={this.state.navClass} heightRef={(height) => this.setState({height}, this.bindScroll)}/>
          <div className="main Admin-main container-fluid">
            {this.props.children}
            <div className='clearfix' />
          </div>
          <Footer />
        </section>
      </Authenticated>
    );
  }
}

export default Admin;
