import React, { PureComponent } from 'react'
import DropIn from 'braintree-web-drop-in';
import './braintree-drop-in.css'

const tokenizationKey = 'sandbox_9g8gy5g4_pvw5p86v7gvh99d2'

export default class BraintreeDropIn extends PureComponent {
  constructor(props) {
    super(props)
    this.state = {  }
  }

  createDropIn = async (dropInContainer) => {
    if(this.state.dropInContainer) return false
    try {
      const dropInForm = await DropIn.create({
              authorization: tokenizationKey,
              container: dropInContainer,
              locale: 'en_US',
              paypal: {
                flow: 'checkout',
                amount: this.props.amount || 0,
                currency: 'USD',
                commit: false
              }
            })

      this.setState({
        dropInForm,
        dropInContainer
      })
    } catch (e) {
      console.error(e);
    }
  }

  getPaymentDetails = async (ev) => {
    try {
      ev.preventDefault()
      ev.stopPropagation()
      const result = await this.state.dropInForm.requestPaymentMethod()
      this.props.onComplete(result)
    } catch (err) {
      console.error(err);
    }
  }

  render() {
    return (
      <div className="dropin-wrapper">
        <div ref={this.createDropIn} className='dropin-container form-group'></div>
        <button
          type='button'
          className="btn-lg btn-primary btn-block"
          onClick={this.getPaymentDetails}
        >
          {this.props.submitMessage || 'Enter Payment Details'}
        </button>
      </div>
    )
  }
}
