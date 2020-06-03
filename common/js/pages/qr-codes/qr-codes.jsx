import React, { Component } from 'react'
import { CardSection } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import FileDownload from 'common/js/components/file-download'
import dusIdFormat from 'common/js/helpers/dus-id-format'
import './qr-codes.css'

const withHttp = (src) => /:\/\//.test(src) ? src : `https://${src}`

export default class QrCodesPage extends Component {
  state = {
    url: '',
    dusId: '',
    amount: '',
    img: false,
    imgUrl: '',
    errors: false
  }

  setStateAsync = (newState) => new Promise((r) => this.setState(newState, () => r(this.state)))

  getUrlCode = async () =>
    this.wrapFunction(() => {
      if(/[a-z]+\.[a-z]+(\/|\?|$)/i.test(this.state.url)) return this.getCode(withHttp(this.state.url), { url: '' })

      throw new Error("Invalid URL")
    })

  getPaymentCode = async () =>
    this.wrapFunction(() => {
      const dusId = dusIdFormat(this.state.dusId)
      const amount = this.state.amount

      if(!/^[A-Z]{3}-[A-Z]{3}/.test(dusId)) throw new Error("Invalid DUS ID")
      if(amount && !/\d+(\.\d{2})?/.test(amount)) throw new Error("Invalid Suggested Amount")

      return this.getCode(`https://www.downundersports.com/payment/${dusId}${amount ? `?amount=${amount}` : ''}`, { dusId: '', amount: '' })
    })

  getCode = async (url, state) => {
    try {
      url && this.setState({ img: `/api/qr_codes/${encodeURIComponent(btoa(url))}`, imgUrl: url, errors: false, ...(state || {}) })
    } catch(err) {
      this.setState({ img: false, imgUrl: '' })
      throw err
    }
  }

  formatDusId = () =>
    this.setState({ dusId: dusIdFormat(this.state.dusId) })

  onUrlChange = (ev) =>
    this.onChange(ev, 'url')

  onDusIdChange = (ev) =>
    this.onChange(ev, 'dusId')

  onAmountChange = (ev) =>
    this.onChange(ev, 'amount')

  onChange = (ev, key) => {
    this.setState({ [key]: ev.currentTarget.value || '', errors: false })
  }

  wrapFunction = async (func) => {
    try {
      return await func()
    } catch (err) {
      return this.handleError(err)
    }
  }

  handleError = async (err) => {
    try {
      const errorResponse = await err.response.json()
      console.log(errorResponse)
      return await this.setStateAsync({errors: errorResponse.errors || [ errorResponse.message ], submitting: false})
    } catch(e) {
      console.error(err)
      return await this.setStateAsync({errors: [ err.message ], submitting: false})
    }
  }

  render(){
    return (
      <CardSection
        className="my-5"
        label="Boost your Fundraising with a Custom QR Code!"
      >
        <p>
          Use the form(s) below to generate branded QR Codes that you can print
          on flyers, posters, etc. so potential donors can scan the code with their
          smart phone for easy access.  You can even set a suggested amount for
          donors to give; your personalized payment page will automatically select
          that amount for them to donate!
        </p>
        <hr/>
        <div className="row">
          <div className="col">
            {
              this.state.errors && <div className="alert alert-danger form-group" role="alert">
                {
                  this.state.errors.map((v, k) => (
                    <div className='row' key={k}>
                      <div className="col">
                        { v }
                      </div>
                    </div>
                  ))
                }
              </div>
            }
          </div>
        </div>
        <div className="row form-group">
          <div className="col-md border-right">
            <div className="row">
              <div className="col-12">
                <h4 className="text-center">
                  Payment Link
                </h4>
              </div>
              <div className="col">
                <TextField
                  id="qr_code_dus_id"
                  name="qr_code_dus_id"
                  value={this.state.dusId}
                  label="DUS ID"
                  onChange={this.onDusIdChange}
                  onBlur={this.formatDusId}
                  className="form-control"
                  placeholder="(AAA-AAA)"
                />
              </div>
              <div className="col">
                <TextField
                  id="qr_code_amount"
                  name="qr_code_amount"
                  value={this.state.amount}
                  label={
                    <span>
                      Suggested Amount <small>(Optional)</small>
                    </span>
                  }
                  onChange={this.onAmountChange}
                  className="form-control"
                  placeholder="(10.00)"
                  useCurrencyFormat
                />
              </div>
              <div className="col-12 mt-3">
                <button className="btn btn-block btn-primary" type="button" onClick={this.getPaymentCode}>
                  Generate!
                </button>
              </div>
            </div>
            <hr/>
            <div className="row">
              <div className="col-12">
                <h4 className="text-center">
                  Other URL
                </h4>
              </div>
              <div className="col">
                <TextField
                  id="qr_code_url"
                  name="qr_code_url"
                  value={this.state.url}
                  label="URL"
                  onChange={this.onUrlChange}
                  className="form-control"
                />
              </div>
              <div className="col-auto">
                <label>&nbsp;</label>
                <button className="btn btn-block btn-primary" type="button" onClick={this.getUrlCode}>
                  Generate!
                </button>
              </div>
            </div>
          </div>
          <div className="col" style={{maxWidth: '500px'}}>
            {
              this.state.img && (
                <>
                  <FileDownload key="downloadImg" path={this.state.img}>
                    <div key="img" className="qr-code-wrapper clickable">
                      <div className="qr-code">
                        <img src={this.state.img} alt="Generated QR Code" />
                      </div>
                      <div className="qr-code-footer">
                        Generated Code <br/>
                        (Click to Save)
                      </div>
                    </div>
                  </FileDownload>

                  <a key="link" className="btn btn-block btn-dark" href={withHttp(this.state.imgUrl)} rel="noopener noreferrer" target="_qrcode">{withHttp(this.state.imgUrl)}</a>
                </>

              )
            }
          </div>
        </div>
      </CardSection>
    )
  }
}
