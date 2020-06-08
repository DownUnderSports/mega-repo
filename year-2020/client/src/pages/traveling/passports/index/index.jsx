import React           from 'react';
import AsyncComponent  from 'common/js/components/component/async'
import FileDownload    from 'common/js/components/file-download'
import LookupTable     from 'common/js/components/lookup-table'
import CalendarField   from 'common/js/forms/components/calendar-field'
import ETAValuesForm   from 'forms/eta-values-form'

const passportsUrl = '/admin/traveling/passports',
      headers = [
        'team_name',
        'dus_id',
        'departing_date',
        'first_checker',
        'second_checker',
        'has_eta',
        'extra_processing'
      ],
      aliasFields = {
        extra_processing: 'extra_eta_processing',
        first_checker: 'first_checker_name',
        second_checker: 'second_checker_name',
      },
      copyFields = [
        'dus_id'
      ]

export default class TravelingPassportsIndexPage extends AsyncComponent {
  filterComponent = (h, v, onChange, defaultComponent) =>
    /_date/.test(h) ? (
      <div className="row text-dark">
        <div className='col'>
          <CalendarField
            measurable
            closeOnSelect
            skipExtras
            className='form-control'
            name={h}
            type='text'
            pattern={"\\d{4}-\\d{2}-\\d{2}"}
            onChange={(e, o) => onChange(h, o.value)}
            value={v}
          />
        </div>
      </div>
    ) : (
      /has_|extra_/.test(h) ? (
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
    )

  renderButtons = () => (
    <div className="row">
      <div className="col-auto form-group">
        <FileDownload key="xlsxDownload" path={`${passportsUrl}.csv`}>
          <span key="xlsxDownloadButton" className="btn btn-primary clickable btn-info">
            Passport Status List
          </span>
        </FileDownload>
      </div>
      <div className='col'></div>
    </div>
  )

  rowClassName(u){
    return 'clickable'
  }

  render() {
    return (
      <div className="Passports IndexPage row">
        <LookupTable
          url={passportsUrl}
          headers={headers}
          copyFields={copyFields}
          aliasFields={aliasFields}
          initialSearch={true}
          filterComponent={this.filterComponent}
          renderButtons={this.renderButtons}
          rowClassName={this.rowClassName}
          localStorageKey="adminPassportsIndexState"
          idKey="dus_id"
          resultsKey="passports"
          tabKey="passport"
          className="col-12"
        />
        <div className="col-12">
          <hr/>
        </div>
        <div className="col-12">
          <ETAValuesForm />
        </div>
      </div>
    );
  }
}
