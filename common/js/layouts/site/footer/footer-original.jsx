import React, { PureComponent } from 'react'

import { CompanyInfo, FooterLinks } from './components'
import './footer.css';
import insurancePDF from 'common/assets/pdfs/insurance.pdf'
// import fb from 'common/assets/images/facebook/blue.svg'
// import travelex from 'common/assets/images/travelex.png'
// import bbbFront from 'common/assets/images/bbb/bbb-front.png'
// import bbbBack from 'common/assets/images/bbb/bbb-back.png'

const dateToLocalTime = (d) => d.toLocaleTimeString('en-us',{timeZoneName:'short'}).replace(/:0+/g, '').replace(/[A-Z]+$/, '($&)')

/* MDT FULL */
// const startTime    = new Date('2019-08-31T16:00:00Z').toLocaleTimeString().replace(/:0+/g, ''),
//       longEndTime  = dateToLocalTime(new Date('2019-08-31T00:00:00Z')),
//       shortEndTime = dateToLocalTime(new Date('2019-08-31T19:00:00Z'))

/* MST FULL */
// const startTime    = new Date('2019-11-31T17:00:00Z').toLocaleTimeString().replace(/:0+/g, ''),
//       longEndTime  = dateToLocalTime(new Date('2019-11-31T01:00:00Z')),
//       shortEndTime = dateToLocalTime(new Date('2019-11-31T20:00:00Z'))

/* MDT SUMMER */
const startTime    = new Date('2019-08-31T16:00:00Z').toLocaleTimeString().replace(/:0+/g, ''),
      longEndTime  = dateToLocalTime(new Date('2019-08-31T22:00:00Z')),
      shortEndTime = dateToLocalTime(new Date('2019-08-31T19:00:00Z'))

/* MST SUMMER */
// const startTime    = new Date('2019-11-31T17:00:00Z').toLocaleTimeString().replace(/:0+/g, ''),
//       longEndTime  = dateToLocalTime(new Date('2019-11-31T23:00:00Z')),
//       shortEndTime = dateToLocalTime(new Date('2019-11-31T20:00:00Z'))

export default class Footer extends PureComponent {
  links = [
    {
      to: 'https://www.facebook.com/DownUnderSports',
      target: '_blank',
      rel: 'noopener noreferrer',
      children: [ 'Facebook' ],
    },
    {
      to: "https://www.bbb.org/us/ut/north-logan/profile/athletic-organizations/down-under-sports-1166-2001870/#sealclick",
      target: '_blank',
      rel: 'noopener noreferrer',
      children: [ 'Better Business Bureau' ],
    },
    {
      to: insurancePDF,
      target: '_insurance',
      rel: 'noopener noreferrer',
      children: [ 'Travelex Insurance' ],
    },
    {
      to: '/thank-you-tickets',
      children: [ 'Thank You Ticket Rules' ],
    },
    {
      to: '/open-tryouts',
      children: [ 'Open Tryouts' ],
    },
    {
      to: "/privacy-policy",
      children: [ 'Privacy Policy' ],
    },
    {
      to: '/refunds',
      children: [ 'Refund Policy' ],
    },
    {
      to: '/terms',
      children: [ 'Program Terms' ],
    },
  ]

  render(){
    return (
      <footer className={this.props.className || 'Site-footer'}>
        <div className="footer-content container-fluid">
          <div className="footer-info-wrapper w-100">
            <CompanyInfo />
            <div className="footer-office-hours w-100">
              <table className="table text-light">
                <thead>
                  <tr>
                    <th colSpan="2">
                      Office Hours (Limited)
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <th>
                      Monday - Thursday
                    </th>
                    <td>
                      {startTime} - {longEndTime}
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Friday
                    </th>
                    <td>
                      {startTime} - {shortEndTime}
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Saturday - Sunday
                    </th>
                    <td>
                      Closed
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <FooterLinks
            links={this.links}
          />
        </div>
      </footer>
    )
  }
}
