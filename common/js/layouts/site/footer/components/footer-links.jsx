import React, { PureComponent } from 'react';
import {arrayOf, shape, string, node} from 'prop-types';

import { Link } from 'react-component-templates/components'

export default class FooterLinks extends PureComponent {
  static propTypes = {
    links: arrayOf(shape({
      to: string,
      children: node
    })).isRequired
  }

  mapLink = (props = {}, i) =>
    <Link
      key={i}
      className="footer-link d-flex justify-content-center align-items-center px-3 font-weight-bolder"
      {...props}
    />

  render() {
    const { links = [] } = this.props;
    return (<div className="footer-menu">
      { links.map(this.mapLink) }
    </div>)
  }
}
