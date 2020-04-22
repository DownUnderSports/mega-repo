import React from 'react';
import Component from 'common/js/components/component'
import { Route, Switch } from 'react-router-dom';
import AccountingRemitFormsIndexPage from 'pages/accounting/remit-forms/index'
const url = '/admin/accounting/remit_forms'

export default class AccountingRemitFormsPage extends Component {
  render() {
    return (
      <div className="Accounting IndexPage row">
        <div className="col-12 text-center">
          <Switch>
            <Route
              path={`${url}/:id`}
              component={AccountingRemitFormsIndexPage}
            />
            <Route component={AccountingRemitFormsIndexPage} />
          </Switch>
        </div>
      </div>
    );
  }
}
