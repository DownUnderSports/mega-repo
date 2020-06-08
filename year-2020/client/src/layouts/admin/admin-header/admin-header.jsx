import React, { Component } from 'react'
import { node, string, object } from 'prop-types';
import { withRouter } from 'react-router-dom';

import { Menu } from 'react-component-templates/contexts';
import { debounce } from 'react-component-templates/helpers';

import { HeaderLogo, HeaderLinks } from './components'

import checkVersion from 'common/js/helpers/check-version'
import RouteParser from 'helpers/route-parser'

import './admin-header.css';

const resizeEvents = ['orientationchange', 'resize']

const danger_style = { height: '42px', fontSize: '38px', padding: '2px', lineHeight: 1 }

class Header extends Component {
  static propTypes = {
    title: node,
    navClass: string,
    history: object
  }

  constructor(props) {
    super(props)
    this.state = {}
    props.history.listen(this.getTitle)
  }

  componentDidMount(){
    this.bindResize()
    RouteParser.setPath(this.props.location)
    .then((result) => this.setState({...result}))
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

  onTitleClick = () => {
    this._clicked = (this._clicked || 0) + 1
    if(this._clicked === 6) {
      window.document.dispatchEvent(new CustomEvent(
        'openQueueViewer',
        {
          detail: undefined,
          bubbles: true,
          cancelable: false,
        }
      ))
    }

    setTimeout(() => {
      this._clicked = this._clicked - 1
    }, 2000)
  }

  _getNotifications = async () => {
    if (Notification.permission === "default") {
      try {
        const permission = await Notification.requestPermission()
        if (permission === "granted") {
          new Notification("Ready!");
        }
      } catch(err) {
        console.error(err)
      }
    }
  }

  get chatHeaderClass() {
    const latestView = new Date(this.props.chatRoomContext.latestView || 0),
          latestMessage = new Date(this.props.chatRoomContext.latestMessage || 0),
          open = !!this.props.chatRoomContext.open
    return `${latestMessage > latestView ? 'notify' : ''} ${open ? '' : 'text-danger'}`
  }

  render(){
    return (
      <header ref={(el) => this.headerEl = el} className="Admin-header">
        <nav className="navbar navbar-expand navbar-light bg-light w-100vw">
          <HeaderLogo />
          <HeaderLinks
            links={[
              {
                to: "/admin/accounting",
                children: 'Accounting',
              },
              {
                to: '/admin/traveling',
                children: 'Traveling'
              },
              {
                to: '/admin/returned_mails',
                children: 'Mail'
              },
              {
                to: '/admin/schools',
                children: 'Schools'
              },
              {
                to: '/admin/assignments',
                children: 'Assignments'
              },
              {
                to: '/admin/users',
                children: 'Search'
              }
            ]}
          />
          <div className="ml-auto navbar-brand" onClick={this.onTitleClick}>
            {(this.state.title || (<span>Users</span>))}
          </div>
        </nav>
        <div className="bg-danger text-light" style={danger_style}>
          YEAR 2020
        </div>
      </header>
    )
  }
}

export default Menu.Decorator(
  withRouter(Header)
)
