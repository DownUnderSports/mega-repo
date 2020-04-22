import React from 'react'
import Component from 'common/js/components/component'
import flashMessage from 'common/js/helpers/flash-message'
import Confirmation from 'common/js/forms/components/confirmation';

export default class MethodLink extends Component {
  state = { showConfirmation: false }

  get url() {
    return String(this.props.url || window.location.pathname)
  }

  get method() {
    return String(this.props.method || 'GET').toUpperCase()
  }

  get fetchProps() {
    return this.props.fetchProps || {}
  }

  get renderProps() {
    const {
      url: _url,
      method: _method,
      fetchProps: _fetchProps,
      confirmationMessage: _confirmationMessage,
      confirmationTitle: _confirmationTitle,
      ...props
    } = this.props
    return props || {}
  }

  get confirmationMessage() {
    return this.props.confirmationMessage || ''
  }

  get confirmationTitle() {
    return this.props.confirmationTitle || 'Please Confirm The Action Below'
  }

  onClick = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    if(this.confirmationMessage) this.setState({ showConfirmation: true })
  }

  runMethod = async () => {
    if(this._isMounted) this.setState({ showConfirmation: false })

    try {
      const result = await (this._fetchingResource = fetch(this.url, { method: this.method, ...this.fetchProps })),
            json = await result.json()

      this.onSuccess(json)
    } catch(err) {
      let errors

      try {
        const values = await err.response.json()
        
        errors = values.errors || [ values.error ]
      } catch(e) {
        errors = [ err.toString() ]
      }

      this.onError(errors)
    }
  }

  onSuccess = (json) => (this.props.onSuccess && this.props.onSuccess(json)) || flashMessage(json.message || 'Success')
  onError = (errors) => (this.props.onError && this.props.onError(errors)) || flashMessage(errors.join('; ') || 'Error')
  onConfirmationError = ()=> {
    this.setState({ showConfirmation: false })
    this.onError([ 'Canceled' ])
  }

  render() {
    return this.state.showConfirmation
      ? (
          <Confirmation
            title={this.confirmationTitle}
            onConfirm={this.runMethod}
            onCancel={this.onConfirmationError}
          >
            { this.confirmationMessage }
          </Confirmation>
        )
      : (
          <button {...this.renderProps} type="button" onClick={this.onClick} />
        )
  }
}
