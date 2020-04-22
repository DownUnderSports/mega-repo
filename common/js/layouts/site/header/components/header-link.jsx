import React, { PureComponent } from 'react';
import { Link } from 'react-component-templates/components'

export default class HeaderLink extends PureComponent {
  render() {
    const { className, ...props } = this.props
    return (
      <Link
        className={`nav-link header-link ${className || ''}`}
        {...props}
      />
    )
  }
}
