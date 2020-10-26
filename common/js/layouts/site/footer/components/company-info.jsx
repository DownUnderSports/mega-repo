import React, { PureComponent } from 'react';
import CopyClip from 'common/js/helpers/copy-clip'
/*
<br/>
Physical Location: <br className='d-sm-none'/><a
  data-content='physical'
  href="https://maps.google.com/?q=Down Under Sports, 1755 N 400 E #201, North Logan, UT 84341-6010">
  1755 N 400 E Ste 201, North Logan, UT 84341-6010
</a>
*/
export default class CompanyInfo extends PureComponent {
  copyMailingAddress(e) {
    e.preventDefault()
    CopyClip.prompted(e.target.innerText)
  }

  render() {
    return (
      <address>
        <strong>
          <i>
            Down Under Sports
          </i>
        </strong>
        <br/>
        Phone (Call/Text): <a data-content='phone' href="tel:+1-435-753-4732">435-753-4732</a>
        <br/>
        Email: <a data-content='email' href="mailto:mail@downundersports.com">mail@downundersports.com</a>
        <br/>
        Mailing Address: <br className='d-sm-none'/><a
          data-content='mailing'
          href="/"
          onClick={this.copyMailingAddress}
        >
          PO Box 6010, North Logan, UT 84341-6010
        </a>
      </address>
    )
  }
}
