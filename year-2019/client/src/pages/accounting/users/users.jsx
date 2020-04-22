import React from 'react';
import LookupTable from 'common/js/components/lookup-table'
import canUseDOM from 'common/js/helpers/can-use-dom'
import {
  headers as ogHeaders,
  aliasFields as ogAliasFields,
  additionalFilters,
  copyFields,
  colors,
  default as OriginalComponent
} from 'pages/users/index'

const accountingUsersUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/accounting/users`,
      headers = [
        ...ogHeaders,
        'payments',
        'debits',
        'credits',
        'charges',
        'balance',
      ],
      aliasFields = {
        balance: 'current_balance',
        charges: 'total_charges',
        credits: 'total_credited',
        debits: 'total_debited',
        payments: 'total_paid',
        ...ogAliasFields,
      }

export default class AccountingUsersPage extends OriginalComponent {
  render() {
    return (
      <div className="Accounting RespondsPage row">
        <LookupTable
          additionalFilters={additionalFilters}
          aliasFields={aliasFields}
          colors={colors}
          className="col-12"
          copyFields={copyFields}
          filterComponent={this.filterComponent}
          headers={headers}
          idKey="dus_id"
          initialSearch={true}
          localStorageKey="adminAccountingPaymentsByUser"
          renderButtons={this.renderButtons}
          resultsKey="users"
          rowClassName={this.rowClassName}
          showUrl="/admin/users"
          tabKey="user"
          url={accountingUsersUrl}
        />
      </div>
    );
  }
}
