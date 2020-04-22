import React, { Component } from 'react';
import PropTypes from 'prop-types';

/**
 * Display buttons as html links
 * @extends React.Component
 */
export default class AntiLink extends Component {
  /**
   * @type {object}
   * @property {string} label - aria-label
   * @property {string} className - additional html classes (space separated)
   * @property {string} children - Button HTML or Text
   */
  static propTypes = {
    label: PropTypes.string.isRequired,
    className: PropTypes.string
  }

  /**
   * Render Anti-Link
   * @return {ReactElement} markup
   */
  render() {
    const {label, className = '', ...props} = this.props;
    return (<button type="button" className={`anchor-button ${className}`} aria-label={label} {...props} />)
  }
}
