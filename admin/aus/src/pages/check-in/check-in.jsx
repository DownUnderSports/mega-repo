import React, { Component } from 'react';
import OutboundInternationalFlight from 'models/components/outbound-international-flight'
import DisplayFlights from './components/display-flights'
import Authenticated from 'components/authenticated'

export default class CheckInPage extends Component {
  render() {
    return (
      <div className="Page OutboundInternationalFlightsPage">
        <div className="row">
          <div className="col">
            <Authenticated allowDusId dusIdFirst>
              <OutboundInternationalFlight>
                <DisplayFlights />
              </OutboundInternationalFlight>
            </Authenticated>
          </div>
        </div>
      </div>
    );
  }
}
