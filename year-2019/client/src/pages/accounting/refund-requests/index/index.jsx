import React, { Component } from 'react';
import LookupTable from 'common/js/components/lookup-table'
import CalendarField from 'common/js/forms/components/calendar-field'

const accountingRefundRequestsUrl = '/admin/accounting/refund_requests',
      headers = [
        'dus_id',
        'created_at',
      ],
      copyFields = [
        'dus_id'
      ]

export default class AccountingRefundRequestsIndexPage extends Component {
  filterComponent = (h, v, onChange, defaultComponent) =>
    /_date|_at/.test(h) ? (
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

  render() {
    return (
      <div className="Accounting RefundRequests IndexPage row">
        <LookupTable
          className="col-12"
          copyFields={copyFields}
          filterComponent={this.filterComponent}
          headers={headers}
          idKey="id"
          initialSearch={true}
          localStorageKey="adminAccountingRefundRequests"
          renderButtons={this.renderButtons}
          resultsKey="refund_requests"
          rowClassName={this.rowClassName}
          showUrl="/admin/accounting/refund_requests"
          tabKey="_refund_request"
          url={accountingRefundRequestsUrl}
        />
      </div>
    );
  }
}
