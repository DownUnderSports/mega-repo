import React          from 'react';
import AsyncComponent from 'common/js/components/component/async'
import LookupTable    from 'common/js/components/lookup-table'

const eventResultsUrl = '/admin/traveling/event_results',
      headers = [
        'sport_abbr',
        'name',
      ]

export default class TravelingEventResultsIndexPage extends AsyncComponent {
  rowClassName(u){
    return 'clickable'
  }

  render() {
    return (
      <div className="EventResults IndexPage row">
        <LookupTable
          url={eventResultsUrl}
          headers={headers}
          initialSearch={true}
          rowClassName={this.rowClassName}
          localStorageKey="adminEventResultsIndexState"
          resultsKey="event_results"
          idKey="id"
          tabKey="bus"
          className="col-12"
        />
      </div>
    );
  }
}
