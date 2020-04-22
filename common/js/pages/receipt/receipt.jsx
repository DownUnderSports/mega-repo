import React, {Component, Fragment} from 'react'
import pixelTracker from 'common/js/helpers/pixel-tracker'
import dateFns from 'date-fns'
import './receipt.css'
const paymentUrl = '/api/payments'

export default class ReceiptPage extends Component {
  constructor(props){
    super(props)
    this.state = {
      formatted_amount: '$0.00',
      payment: {},
      items: [],
      status: '',
      error: false,
    }
  }

  getReceipt = () => {
    return new Promise((res) => {
      this.setState({loading: true, error: false}, async () => {
        try {
          const result = await fetch(`${paymentUrl}/${this.findId(this.props)}`),
                {
                  formatted_amount = '$0.00',
                  payment = {},
                  items = [],
                  status = 'failed'
                } = await result.json()

          this.setState({
            loading: false,
            formatted_amount,
            payment,
            items,
            status
          }, res)

        } catch(e) {
          console.error(e)
          this.setState({
            error: true,
            loading: false,
            formatted_amount: '$0.00',
            payment: {},
            items: []
          }, res)
        }
      })
    })
  }

  findId(props){
    try {
      const id = props.match.params.id
      return id
    } catch(e) {
      console.error(e)
      return e
    }
  }

  async componentDidMount(){
    pixelTracker('track', 'PageView')
    await this.getReceipt(this.props)
  }

  componentDidUpdate(prevProps){
    if(this.findId(this.props) !== this.findId(prevProps)) this.getReceipt()
  }

  printReceipt(){
    try {
      window.scroll(0,0)
    } catch (e) {
      window.scrollTo(0,0)
    } finally {
      try {
        window.print()
      } catch (e) {
        alert("Direct printing is not supported on your device. Instead, please click the print button in the settings menu on your device.")
      }
    }
  }

  renderError() {
    return (
      <section className="receipt-container">
        <header>
          <h3>Invalid Link</h3>
        </header>
        <p className="text-center">
          The requested payment was not found, or the link has expired.
        </p>
      </section>
    )
  }

  render(){
    const {
      formatted_amount = '$0.00',
      payment = {},
      items = [],
      status = '',
      error = false
    } = this.state

    if(error) return this.renderError()

    const pending = status === 'PENDING REVIEW'

    const {amount = {str_pretty: '$0.00'}, created_at = "2017-01-01T00:00:00.000-06:00", label = 'Payment', billing = {}, gateway = {}, itemized = false} = payment
    let payDate = created_at && dateFns.format(dateFns.parse(created_at), 'DD MMM, YYYY HH:MM A')

    return (
      <section className="receipt-container">
        <div className="print-fix">
          <header className='receipt-header text-center'>
            <h3>Down Under Sports {label} Receipt{pending ? <> - <span className="text-warning">PENDING</span></> : ""}</h3>
            {
              (
                itemized && (
                  <h4>
                    {label}s will be processed within 5 days of submission.
                  </h4>
                )
              ) || (<span></span>)
            }
          </header>
          <div className="row">
            <div className="col-md form-group">
              {
                (billing.street_address && (
                  <address>
                    {
                      billing.company ? <Fragment>
                        <strong key='1'>{billing.company}</strong>
                        <br key='2'/>
                      </Fragment> : ''
                    }
                    <strong>{billing.name || `${billing.first_name} ${billing.last_name}`}</strong><br/>
                    { billing.street_address }<br/>
                    { billing.extended_address } {billing.extended_address ? <br/> : ''}
                    {`${billing.locality}, ${billing.region} ${billing.postal_code}`}<br/>
                    {billing.country_code_alpha3}<br/>
                    <abbr title="Card Holder Email">
                      <a href={'mailto:' + billing.email}>
                        {billing.email}
                      </a>
                    </abbr><br/>
                    <abbr title="Card Holder Phone">
                      <a href={'tel:' + billing.phone}>
                        {billing.phone}
                      </a>
                    </abbr>
                  </address>
                )) || (
                  <address>
                    <strong>{`${billing.first_name} ${billing.last_name}`}</strong><br/>
                  </address>
                )
              }
            </div>
            <div className="col-md form-group">
              {
                gateway.trans_id && (<div className="row">
                  <div className="col-sm">
                    Transaction ID:
                  </div>
                  <div className="col-sm">
                    {gateway.trans_id}
                  </div>
                </div>)
              }
              <div className="row">
                <div className="col-sm">
                  Date:
                </div>
                <div className="col-sm">
                  {payDate}
                </div>
              </div>
              <div className="row">
                <div className="col-sm">
                  Card Number:
                </div>
                <div className="col-sm">
                  {gateway.account_number}
                </div>
              </div>
              <div className="row">
                <div className="col-sm">
                  Card Type:
                </div>
                <div className="col-sm">
                  {gateway.account_type}
                </div>
              </div>
            </div>
          </div>

          <section>
            <header>
              <h4>Purchase Information</h4>
            </header>
            <br/>
            <div className="d-none d-sm-block table-responsive">
              <table className='table table-bordered'>
                <thead className='thead-inverse'>
                  <tr>
                    <th>Item</th>
                    <th>Description</th>
                    <th>Price</th>
                    <th>Quantity</th>
                    <th>Total</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map(
                    (item, i) =>
                    <tr key={i}>
                      <td>
                        {item.name}
                      </td>
                      <td>
                        {item.description}
                      </td>
                      <td>
                        {item.price ? item.price.str_pretty : '$0.00'}
                      </td>
                      <td>
                        {item.quantity}
                      </td>
                      <td>
                        {item.amount ? item.amount.str_pretty : '$0.00'}
                      </td>
                    </tr>
                  )}
                </tbody>
                <tfoot>
                  <tr className='table-info'>
                    <td colSpan='4'>Total</td>
                    <td>
                      {
                        (amount && amount.str_pretty) ||
                        formatted_amount
                      }
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
            <div className="d-block d-sm-none table-responsive border-bottom">
              {items.map(
                (item, i) =>
                <div className='row' key={i}>
                  <div className="col-12">
                    <p>
                      <strong>
                        {item.name}:
                      </strong>
                      {item.description}
                    </p>
                  </div>
                  <div className="col-12 border-bottom">
                    Price: {item.price ? item.price.str_pretty : '$0.00'}<br/>
                    Qty: {item.quantity || 1}<br/>
                    Item: {item.amount ? item.amount.str_pretty : '$0.00'}<br/>
                  </div>
                </div>
              )}
              Total: { (amount && amount.str_pretty) || formatted_amount }
            </div>
            {
              pending && (
                <div className="row my-3">
                  <div className='col'>
                    <div className="text-danger text-center p-1">
                      <p>
                        <b>
                          This Payment has Triggered our Fraud Detection Suite for Further Review
                        </b>
                      </p>
                      <p>
                        If your payment is rejected, any monies paid will be returned and the items above will be removed.
                      </p>
                      <p>
                        No further action is required from you at this time.
                      </p>
                    </div>
                  </div>
                </div>
              )
            }
          </section>
          <section className='footnote'>
            <div className="row">
              <div className="col-sm form-group">
                <p className='ellipses'>
                  Down Under Sports Refund policy can be reviewed at any time by visiting <a href="https://downundersports.com/refunds">https://downundersports.com/refunds</a>
                </p>
              </div>
              <div className='d-print-none col-auto'>
                <button onClick={this.printReceipt}><i className="material-icons">print</i> Print Receipt</button>
              </div>
            </div>
          </section>

        </div>
      </section>
    )
  }
}
