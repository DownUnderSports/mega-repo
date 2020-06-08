import React          from 'react';
import AsyncComponent from 'common/js/components/component/async'
import FileDownload   from 'common/js/components/file-download'
import LookupTable    from 'common/js/components/lookup-table'
import CalendarField  from 'common/js/forms/components/calendar-field'

const schedulesUrl = '/admin/traveling/flights/schedules',
      headers = [
        'pnr',
        'operator',
        'departing',
        'arriving',
        'from',
        'to',
        'cpnr',
        'names',
        'users',
        'cancels',
        'rsvd',
        'summary',
        'booking',
      ],
      aliasFields = {
        arriving: 'arriving_at',
        to: 'arriving_to',
        booking: 'booking_reference',
        cancels: 'cancels_count',
        cpnr: 'carrier_pnr',
        departing: 'departing_at',
        from: 'departing_from',
        names: 'names_assigned',
        users: 'totals_count',
        summary: 'route_summary',
        rsvd: 'seats_reserved'
      },
      copyFields = [
        'pnr'
      ]

export default class SchedulesIndexPage extends AsyncComponent {
  filterComponent = (h, v, onChange, defaultComponent) =>
    /arriving|departing/.test(String(h)) ? (
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
    ) : defaultComponent(h, v)

  rowClassName(u){
    // return `clickable ${u.contactable ? (u.traveling ? (u.cancel_date ? 'bg-warning-light' : 'bg-success') : '') : 'bg-danger'}`
    return 'clickable'
  }

  button(){

  }

  renderButtons = ({onChange, tableState}) => (
    <div className="row">
      <div className="col-auto form-group">
        <FileDownload key="xlsxDownload" path={`${schedulesUrl}.xlsx`} emailed>
          <span key="xlsxDownloadButton" className="btn btn-primary clickable btn-info">
            Download Worksheet
          </span>
        </FileDownload>
      </div>
      <div className="col-auto form-group">
        <FileDownload key="xlsxDownload" path={`${schedulesUrl}/srdocs.xlsx`} emailed>
          <span key="xlsxDownloadButton" className="btn btn-primary clickable btn-info">
            Download SR Docs
          </span>
        </FileDownload>
      </div>
      <div className="col-auto form-group">
        <FileDownload key="xlsxDownload" path={`${schedulesUrl}/air_canada.xlsx`} emailed>
          <span key="xlsxDownloadButton" className="btn btn-primary clickable btn-info">
            Download Air Canada
          </span>
        </FileDownload>
      </div>
      <div className="col-auto form-group">
        <FileDownload key="xlsxDownload" path={`${schedulesUrl}/virgin_australia.xlsx`} emailed>
          <span key="xlsxDownloadButton" className="btn btn-primary clickable btn-info">
            Download Virgin Australia
          </span>
        </FileDownload>
      </div>
      <div className='col'></div>
    </div>
  )

  render() {
    return (
      <div className="Schedules IndexPage row">
        <LookupTable
          url={schedulesUrl}
          headers={headers}
          initialSearch={true}
          aliasFields={aliasFields}
          copyFields={copyFields}
          filterComponent={this.filterComponent}
          renderButtons={this.renderButtons}
          rowClassName={this.rowClassName}
          localStorageKey="adminSchedulesIndexState"
          resultsKey="schedules"
          idKey="pnr"
          tabKey="schedule"
          className="col-12"
        />
      </div>
    );
  }
}
