import React          from 'react';
import AsyncComponent from 'common/js/components/component/async'
import LookupTable    from 'common/js/components/lookup-table'

const competingTeamsUrl = '/admin/traveling/ground_control/competing_teams',
      headers = [
        'sport_abbr',
        'name',
        'letter',
        'assigned',
      ]

export default class TravelingGroundControlCompetingTeamsIndexPage extends AsyncComponent {
  rowClassName(u){
    return 'clickable'
  }

  render() {
    return (
      <div className="CompetingTeams IndexPage row">
        <LookupTable
          url={competingTeamsUrl}
          headers={headers}
          initialSearch={true}
          rowClassName={this.rowClassName}
          localStorageKey="adminCompetingTeamsIndexState"
          resultsKey="competing_teams"
          idKey="id"
          tabKey="bus"
          className="col-12"
        />
      </div>
    );
  }
}
