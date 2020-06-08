import React, { PureComponent } from 'react';
import { Link } from 'react-component-templates/components'
import logo from 'common/assets/images/dus-logo.png';

export default class HeaderLogo extends PureComponent {
  render() {
    return (
      <div className="header-logo navbar-brand" {...this.props}>
        <Link to='/admin/' className="header-link">
          <img src={logo} alt='Admin Logo' />
        </Link>
      </div>
    )
  }
}
