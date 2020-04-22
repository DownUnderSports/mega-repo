import React, { Component} from 'react';

export default class ProxyPage extends Component {
  html = { __html: window.originalHTML }
  render() {
    return (
      <div dangerouslySetInnerHTML={this.html} />

    );
  }
}
