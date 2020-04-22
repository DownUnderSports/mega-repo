import React, { Component } from 'react';
import canUseDOM from 'common/js/helpers/can-use-dom'
import { string, func, oneOf } from 'prop-types';

export default class Recaptcha extends Component {
  static propTypes = {
    className: string,
    elementID: string,
    onLoad: func,
    onVerify: func,
    onExpired: func,
    onLoadCallbackName: string,
    verifyCallbackName: string,
    expiredCallbackName: string,
    render: oneOf(['onload', 'explicit']),
    sitekey: string,
    theme: oneOf(['light', 'dark']),
    type: string,
    size: oneOf(['invisible', 'compact', 'normal']),
    tabindex: string,
    hl: string,
    badge: oneOf(['bottomright', 'bottomleft', 'inline']),
  }

  static defaultProps = {
    elementID: 'g-recaptcha',
    className: 'g-recaptcha',
    onLoad: undefined,
    onLoadCallbackName: 'onLoad',
    onVerify: undefined,
    verifyCallbackName: 'onVerify',
    onExpired: undefined,
    expiredCallbackName: 'onExpired',
    render: 'onload',
    theme: 'light',
    type: 'image',
    size: 'normal',
    tabindex: '0',
    hl: 'en',
    badge: 'bottomright',
  }

  static isReady = () => canUseDOM
    && typeof window.grecaptcha !== 'undefined'
    && typeof window.grecaptcha.render === 'function';

  constructor(props) {
    super(props);
    this.state = {
      ready: false,
      widget: null,
    };
  }

  readyCheck = (resolve, reject) => {
    if(this.constructor.isReady()) resolve(true)
    this.readyInterval = setTimeout(() => this.readyCheck(resolve, reject), 250)
  }

  ready = async () => {
    await new Promise(this.readyCheck)

    this.setState({
      ready: true,
      widget: this.gRecaptcha(this.props)
    }, this.props.onLoad || function(){})
  }

  componentDidMount(){
    this.ready()
  }

  componentWillUnmount() {
    clearTimeout(this.readyInterval);
  }

  reset = () => {
    const { ready, widget } = this.state;
    if (ready && widget !== null) {
      window.grecaptcha.reset(widget);
    }
  }

  execute() {
    const { ready, widget } = this.state;
    if (ready && widget !== null) {
      window.grecaptcha.execute(widget);
    }
  }

  gRecaptcha(props) {
    return window.grecaptcha.render(props.elementID, {
      sitekey: props.sitekey,
      callback: (props.onVerify) ? props.onVerify : undefined,
      theme: props.theme,
      type: props.type,
      size: props.size,
      tabindex: (+(this.props.tabIndex || 0) < 0) ? -1 : 0,
      hl: props.hl,
      badge: props.badge,
      'expired-callback': (props.onExpired) ? this.props.onExpired : undefined,
    })
  }

  render() {
    if (this.props.render === 'explicit' && this.props.onLoad) {
      return (
        <div id={this.props.elementID}
          data-onloadcallbackname={this.props.onLoadCallbackName}
          data-verifycallbackname={this.props.verifyCallbackName}
        />
      );
    }

    return (
      <div id={this.props.elementID}
        className={this.props.className}
        data-sitekey={this.props.sitekey}
        data-theme={this.props.theme}
        data-type={this.props.type}
        data-size={this.props.size}
        data-badge={this.props.badge}
        data-tabindex={(+(this.props.tabindex || 0) < 0) ? -1 : 0}
      />
    );
  }
}
