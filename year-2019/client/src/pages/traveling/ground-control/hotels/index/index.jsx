import React          from 'react';
import AsyncComponent from 'common/js/components/component/async'
import LookupTable    from 'common/js/components/lookup-table'
import canUseDOM      from 'common/js/helpers/can-use-dom'

const hotelsUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/traveling/ground_control/hotels`,
      headers = [
        'name',
        'phone',
        'city',
        'area',
        'country',
      ]

export default class TravelingGroundControlHotelsIndexPage extends AsyncComponent {
  rowClassName(u){
    return 'clickable'
  }

  render() {
    return (
      <div className="Hotels IndexPage row">
        <LookupTable
          url={hotelsUrl}
          headers={headers}
          initialSearch={true}
          rowClassName={this.rowClassName}
          localStorageKey="adminHotelsIndexState"
          resultsKey="hotels"
          idKey="id"
          tabKey="hotel"
          className="col-12"
        />
      </div>
    );
  }
}
