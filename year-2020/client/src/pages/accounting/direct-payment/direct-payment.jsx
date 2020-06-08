import React, { Component } from 'react';
import DirectPaymentForm from 'forms/direct-payment-form'

export default class AccountingDirectPaymentPage extends Component {

  render() {
    return (
      <div className="Accounting DirectPaymentPage row">
        <div className="col-12 text-center">
          <h3>Enter Payment Directly</h3>
        </div>
        <div className="col-12">
          <DirectPaymentForm />
        </div>
      </div>
    );
  }
}
