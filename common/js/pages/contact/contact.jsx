import React, { Component } from 'react';
import { Link } from 'react-component-templates/components'
import pixelTracker from 'common/js/helpers/pixel-tracker'

import contactUs from 'common/assets/images/contact-us.webp'

import './contact.css'

class ContactPage extends Component {
  componentDidMount() {
    pixelTracker('track', 'PageView')
  }

  render() {
    return (
      <div className="ContactPage">
        <section className="my-4">
          <header>
            <span className="sr-only">Contact Us</span>
            <img src={contactUs} alt="Contact Us"/>
          </header>
          <p className="text-center">
            Have questions about our program? We would love to answer them for you!
          </p>
          <Link
            className='authBtn'
            to="https://www.meetingbird.com/l/DownUnderSports/one-on-one"
            target="_schedule_appt"
            rel="noopener noreferrer"
          >
            Schedule a One-on-One Appointment
          </Link>
          <hr className="my-5"/>
          <div className="row">
            <div className="col-md">
              <dl>
                <dt>
                  Call:
                </dt>
                <dd>
                  <Link to="tel:+14357534732">(435) 753-4732</Link>
                </dd>
                <dt>
                  Text:
                </dt>
                <dd>
                  <Link to="sms://+14357534732?body=I%20have%20a%20question%20about%20the%20Down%20Under%20Sports%20competitions">(435) 753-4732</Link>
                </dd>
                <dt>
                  Email:
                </dt>
                <dd>
                  <Link to="mailto:mail@downundersports.com">mail@downundersports.com</Link>
                </dd>
                <dt>
                  Address:
                </dt>
                <dd>
                  <Link to="https://g.page/DownUnderSports?share">
                    Down Under Sports<br/>
                    1755 N 400 E, Ste 201<br/>
                    North Logan, UT 84341
                  </Link>
                </dd>
              </dl>
            </div>
            <div className="col-md">
              <dl>
                <dt>
                  Facebook:
                </dt>
                <dd>
                  <Link to="https://facebook.com/DownUnderSports">facebook.com/DownUnderSports</Link>
                </dd>
                <dt>
                  Instagram:
                </dt>
                <dd>
                  <Link to="https://instagram.com/DownUnderSports">instagram.com/DownUnderSports</Link>
                </dd>
                <dt>
                  Twitter:
                </dt>
                <dd>
                  <Link to="https://twitter.com/DownUnderSports">twitter.com/DownUnderSports</Link>
                </dd>
              </dl>
            </div>
          </div>
        </section>
      </div>
    );
  }
}

export default ContactPage;
