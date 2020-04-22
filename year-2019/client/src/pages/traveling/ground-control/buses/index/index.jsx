import React          from 'react';
import AsyncComponent from 'common/js/components/component/async'
import LookupTable    from 'common/js/components/lookup-table'
import canUseDOM      from 'common/js/helpers/can-use-dom'

const busesUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/traveling/ground_control/buses`,
      headers = [
        'sport_abbr',
        'hotel_name',
        'color',
        'name',
        'assigned',
      ]

export default class TravelingGroundControlBusesIndexPage extends AsyncComponent {
  rowClassName(u){
    return 'clickable'
  }

  render() {
    return (
      <div className="Buses IndexPage row">
        <LookupTable
          url={busesUrl}
          headers={headers}
          initialSearch={true}
          rowClassName={this.rowClassName}
          localStorageKey="adminBusesIndexState"
          resultsKey="buses"
          idKey="id"
          tabKey="bus"
          className="col-12"
        />
      </div>
    );
  }
}
