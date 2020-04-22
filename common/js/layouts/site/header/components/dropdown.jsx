import React, { Component } from 'react';
import {arrayOf, oneOfType, shape, string, node} from 'prop-types';
import HeaderLink from './header-link'

const linkShape = shape({
  to: string,
  children: node
})

export default class Dropdown extends Component {
  static propTypes = {
    links: arrayOf(linkShape).isRequired,
    header: oneOfType([
      string,
      node
    ]).isRequired
  }

  componentWillUnmount() {
    document.removeEventListener('click', this.closeClick)
  }

  state = { click: false, hover: false }

  toggleClick = () => {
    console.log('click', this.state.click)
    this.setState({ click: !this.state.click, hover: false }, this.setClickListener)
  }
  closeClick = () => {
    console.log('close click', this.state.click)
    document.removeEventListener('click', this.closeClick)

    this.setState({ click: false, hover: false })
  }
  openHover = () => this.setState({ hover: true })
  closeHover = () => this.setState({ hover: false })

  setClickListener = () => {
    document.removeEventListener('click', this.closeClick)
    this.state.click && document.addEventListener('click', this.closeClick)
  }

  render() {
    return (
      <div
        className={`dropdown clickable nav-link ${this.state.click || this.state.hover}`}
        onMouseEnter={this.openHover}
        onMouseLeave={this.closeHover}
      >
        <div className="dropdown-title" onClick={this.toggleClick}>
          { this.props.header }
          <i className="material-icons">arrow_drop_down</i>
        </div>
        <ul className="dropdown-list">
          {
            this.props.links.map(
              (link, i) =>
                <li key={i} className="dropdown-link">
                  {<HeaderLink key={i} {...link} />}
                </li>
            )
          }
        </ul>
      </div>
    )
  }
}
