import React, { Component } from 'react'

const windowOptions = {
  location: 'no',
  toolbar: 'no',
  resizable: 'no',
  scrollbars: 'yes',
  directories: 'no',
  status: 'no',
  top: '100',
  left: '100',
  width: '960',
  height: '526',
}

const optionsString = Object
  .keys(windowOptions)
  .map(k=>`${k}=${windowOptions[k]}`)
  .join(',')

const code = "17,490F7F0DEC8FAD9C05E44B45EC11A56213A6D942"

const verificationSrc = `https://www.rapidscansecure.com/siteseal/Verify.aspx?code=${code}`
const imgSrc = `https://www.rapidscansecure.com/siteseal/Seal.aspx?code=${code}`

export const verifyPCICompliance = (e) => {
  e.preventDefault()
  window.open(
    verificationSrc,
    'Verification',
    optionsString
  )
  return false;
}

export default class SiteSeal extends Component {
  render() {
    return (
      <button className={`anchor-button ${this.props.className}`} onClick={verifyPCICompliance}>
        <img className={this.props.imgClassName} src={imgSrc} alt="PCI Compliance Site Seal" />
      </button>
    )
  }
}
