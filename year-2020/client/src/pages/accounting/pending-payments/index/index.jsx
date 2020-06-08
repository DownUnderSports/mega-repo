import React, { Component } from 'react';
import LookupTable from 'common/js/components/lookup-table'
import CalendarField from 'common/js/forms/components/calendar-field'

const accountingPendingPaymentsUrl = '/admin/accounting/pending_payments',
      headers = [
        'transaction_id',
        'gateway_type',
        'created_at',
      ],
      copyFields = [
        'transaction_id'
      ]

export default class AccountingPendingPaymentsIndexPage extends Component {
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
      <div className="Accounting PendingPayments IndexPage row">
        <LookupTable
          className="col-12"
          copyFields={copyFields}
          filterComponent={this.filterComponent}
          headers={headers}
          idKey="id"
          initialSearch={true}
          localStorageKey="adminAccountingPendingPayments"
          resultsKey="pending_payments"
          showUrl={accountingPendingPaymentsUrl}
          tabKey="_pending_payment"
          url={accountingPendingPaymentsUrl}
        />
      </div>
    );
  }
}
