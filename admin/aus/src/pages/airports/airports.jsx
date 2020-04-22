/* global navigator */
import React, { Component } from 'react';
import InboundDomesticFlight from 'models/components/inbound-domestic-flight'
import DisplayFlights from './components/display-flights'
import Authenticated from 'components/authenticated'
import CheckInForm          from 'forms/check-in-form'

export default class AirportsPage extends Component {
  getLocation() {
    try {
      if ("geolocation" in navigator) {
        /* geolocation is available */
      } else {
        /* geolocation IS NOT available */
      }
    } catch(e) {
      console.log(e)
    }

  }
  render() {
    return (
      <div className="Page InboundDomesticFlightsPage">
        <Authenticated dusIdFirst>
          <div className="row">
            <div className="col-12 d-print-none">
              <div className="card form-group">
                <h3 className="card-header">
                  Check-In Traveler to International Flight
                </h3>
                <div className="card-body">
                  <CheckInForm />
                </div>
              </div>
            </div>
            <div className="col">
              <InboundDomesticFlight>
                <DisplayFlights />
              </InboundDomesticFlight>
            </div>
          </div>
        </Authenticated>
      </div>
    );
  }
}
