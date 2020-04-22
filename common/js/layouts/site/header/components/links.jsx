import React, { PureComponent } from 'react';
import {arrayOf, oneOfType, shape, string, node} from 'prop-types';
import { Menu } from 'react-component-templates/contexts';

import Dropdown from './dropdown'
import HeaderLink from './header-link'

const linkShape = shape({
  to: string,
  children: node,
  className: string
})

export default class HeaderLinks extends PureComponent {
  static contextType = Menu.Context

  static propTypes = {
    links: arrayOf(
      oneOfType([
        linkShape,
        arrayOf(
          oneOfType([
            linkShape,
            string,
            node
          ])
        )
      ])
    ).isRequired
  }

  isActive = ({ to = '' }) => {
    let active = false
    if((this.props.path === '/') || (to === '/')) active = to === this.props.path
    else active = new RegExp(to).test(this.props.path)

    return  active ? 'active' : ''
  }

  headerLink = ({className, ...props}, i) =>
    <HeaderLink key={i} className={`${this.isActive(props)} ${className || ''}`} {...props} />

  dropdown = ([header, ...links], i) => <Dropdown key={i} header={header} links={links} />


  render() {
    const {
      menuState: { menuOpen },
      menuActions: { toggleMenu },
    } = this.context;


    return (
      <nav className="nav collapsable justify-content-start align-items-center">
        <input
          key="nav-trigger"
          type="checkbox"
          id="nav-trigger"
          className='nav-trigger'
          checked={!!menuOpen}
          readOnly
        />
        <label
          key="nav-trigger-label"
          htmlFor="nav-trigger"
          className="nav-trigger"
          onClick={toggleMenu}
        >
          <span>
            <span></span>
          </span>
        </label>
        {
          (this.props.links || []).map((link, i) => (
            Array.isArray(link)
              ? this.dropdown(link, i)
              : this.headerLink(link, i)
          ))
        }
      </nav>
    )
  }
}
