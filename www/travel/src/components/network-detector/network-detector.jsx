import React, { Component } from 'react'

export default function withNetwork(ChildComponent) {
  class NetworkDetector extends Component {
    state = { offline: !window.navigator.onLine}

    componentDidMount() {
      this.handleConnectionChange();
      window.addEventListener('online', this.handleConnectionChange);
      window.addEventListener('offline', this.handleConnectionChange);
    }

    componentWillUnmount() {
      window.removeEventListener('online', this.handleConnectionChange);
      window.removeEventListener('offline', this.handleConnectionChange);
    }


    handleConnectionChange = () => {
      const condition = navigator.onLine ? 'online' : 'offline';
      if (condition === 'online') {
        const webPing = setInterval(
          () => {
            fetch('//google.com', {
              mode: 'no-cors',
            })
            .then(() => {
              this.setState({ offline: false }, () => {
                return clearInterval(webPing)
              });
            }).catch(() => this.setState({ offline: true }) )
          }, 2000);
        return;
      }

      return this.setState({ offline: true });
    }

    render() {
      return (
        <ChildComponent {...this.props} offline={this.state.offline} />
      )
    }
  }

  return NetworkDetector
}
