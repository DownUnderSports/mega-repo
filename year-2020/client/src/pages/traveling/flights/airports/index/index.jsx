import React          from 'react';
import AsyncComponent from 'common/js/components/component/async'
import LookupTable    from 'common/js/components/lookup-table'

const airportsUrl = '/admin/traveling/flights/airports',
      headers = [
        'code',
        'name',
        'city',
        'area',
        'country',
      ],
      additionalFilters = [
        'preferred',
        'selectable',
      ]

export default class TravelingFlightsAirportsIndexPage extends AsyncComponent {
  filterComponent = (h, v, onChange, defaultComponent) =>
    /selectable|preferred/.test(String(h)) ? (
      <select
        className='form-control'
        onChange={(ev) => onChange(h, ev.target.value)}
        value={v}
      >
        <option value=""></option>
        <option value="TRUE">Yes</option>
        <option value="FALSE">No</option>
      </select>
    ) : defaultComponent(h, v)

  rowClassName(u){
    return 'clickable'
  }

  all = (onChange, tableState) => this.hasSectionFilter(tableState) && onChange({preferred: false, selectable: false})
  preferred = (onChange, tableState) => !tableState.preferred && onChange({preferred: true})
  selectable = (onChange, tableState) => !tableState.selectable && onChange({selectable: true})
  hasSectionFilter = (tableState) => tableState.preferred || tableState.selectable

  renderButtons = ({onChange, tableState}) => (
    <div className="row">
      <div className="col-auto form-group">
        <button
          className='btn btn-info'
          onClick={() => this.preferred(onChange, tableState)}
          disabled={!!tableState.preferred}
        >
          Preferred
        </button>
      </div>
      <div className="col-auto form-group">
        <button
          className='btn btn-info'
          onClick={() => this.selectable(onChange, tableState)}
          disabled={!!tableState.selectable}
        >
          Selectable
        </button>
      </div>
      <div className="col-auto form-group">
        <button
          className='btn btn-info'
          onClick={() => this.all(onChange, tableState)}
          disabled={!this.hasSectionFilter(tableState)}
        >
          All Airports
        </button>
      </div>
      <div className='col'></div>
    </div>
  )

  render() {
    return (
      <div className="Airports IndexPage row">
        <LookupTable
          url={airportsUrl}
          headers={headers}
          additionalFilters={additionalFilters}
          initialSearch={true}
          filterComponent={this.filterComponent}
          rowClassName={this.rowClassName}
          renderButtons={this.renderButtons}
          localStorageKey="adminAirportsIndexState"
          resultsKey="airports"
          idKey="code"
          tabKey="airport"
          className="col-12"
        />
      </div>
    );
  }
}
