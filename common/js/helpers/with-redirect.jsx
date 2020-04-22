import React, { Component } from 'react';
import { Redirect } from 'react-router-dom';

export default (ComposedComponent) => class RedirectDecorator extends Component {
  state = {
    push: false,
    redirectUrl: null,
  }

  componentDidUpdate(prevProps, prevState) {
    const {
      redirectUrl,
    } = this.state;

    // If component is rendered on redirect page as well
    // (i.e. header or footer) it would cause redirect-loop
    // as "<Redirect />" is being rendered every time.
    // So we are resetting the state after redirect
    if (!prevState.redirectUrl && redirectUrl) {
      this.setState({
        push: false,
        redirectUrl: null,
      });
    }
  }

  redirectTo = (redirectUrl, push = false) => {
    this.setState({
      push,
      redirectUrl,
    });
  }

  render() {
    const {
      push,
      redirectUrl,
    } = this.state;

    if (redirectUrl) {
      return <Redirect push={ push } to={ redirectUrl } />;
    }

    return (
      <ComposedComponent
        { ...this.props }
        redirectTo={ this.redirectTo }
      />
    );
  }
};
