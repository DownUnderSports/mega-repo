import React from 'react';
import Component from 'common/js/components/component'
import LookupTable from 'common/js/components/lookup-table'

const accountingRemitFormsUrl = '/admin/accounting/remit_forms',
      headers = [
        'remit_number',
        'positive',
        'negative',
        'net',
        'successful',
        'failed',
        'recorded',
        'reconciled',
      ],
      aliasFields = {
        failed: 'failed_amount',
        negative: 'negative_amount',
        net: 'net_amount',
        positive: 'positive_amount',
        successful: 'successful_amount',
      },
      tooltips = {
        remit_number: 'Remit Number',
        positive: 'Total Amount of successful positive payment items',
        negative: 'Total Amount of successful negative payment items',
        net: 'Total Amount of successful payment items',
        successful: 'Total Attempted Amount of successful payments',
        failed: 'Total Attempted Amount of failed payments',
        recorded: 'Is Recorded?',
        reconciled: 'Is Reconciled?',
      }

export default class AccountingRemitFormsPage extends Component {
  render() {

    return (
      <div className="Accounting RespondsPage row">
        <LookupTable
          url={accountingRemitFormsUrl}
          headers={headers}
          tooltips={tooltips}
          aliasFields={aliasFields}
          initialSearch={true}
          localStorageKey="adminAccountingRemittanceForms"
          resultsKey="remittances"
          idKey="remit_number"
          tabKey="remit_form"
          className="col-12"
          showUrl="/admin/accounting/remit_forms"
        />
      </div>
    );
  }
}
