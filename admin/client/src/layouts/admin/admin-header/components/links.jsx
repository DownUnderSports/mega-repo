import React, { PureComponent } from 'react';
import {arrayOf, shape, string, node} from 'prop-types';

import { Link } from 'react-component-templates/components'

export default class HeaderLinks extends PureComponent {
  static propTypes = {
    links: arrayOf(shape({
      to: string,
      children: node
    })).isRequired
  }

  render() {
    const {links = []} = this.props;
    return (
      <ul className="navbar-nav mr-auto">
        {
          links.map(({className, ...props}, i) => (
            <li className={`nav-item header-link ${className || ''}`} key={i} >
              <Link {...props} />
            </li>
          ))
        }
      </ul>
    )
  }
}
