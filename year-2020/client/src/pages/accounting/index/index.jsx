import React, { Component, Suspense, lazy } from 'react';
import { Route, Switch } from 'react-router-dom';
import { Link } from 'react-component-templates/components';
import { AccountingRefundRequestsShowPage, AccountingRefundRequestsIndexPage } from 'pages/accounting/refund-requests'
import { AccountingPendingPaymentsShowPage, AccountingPendingPaymentsIndexPage } from 'pages/accounting/pending-payments'
import { AccountingBillingLookupsShowPage, AccountingBillingLookupsIndexPage } from 'pages/accounting/billing-lookups'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
const url = '/admin/accounting'

const AccountingDirectPaymentPage = lazy(() => import(/* webpackChunkName: "accounting-direct-payment-page", webpackPreload: true */ 'pages/accounting/direct-payment'))
const AccountingUsersPage          = lazy(() => import(/* webpackChunkName: "accounting-users-page", webpackPrefetch: true */ 'pages/accounting/users'))
const AccountingRemitFormsPage     = lazy(() => import(/* webpackChunkName: "accounting-remit-forms-page", webpackPrefetch: true */ 'pages/accounting/remit-forms'))
const AccountingTransfersPage     = lazy(() => import(/* webpackChunkName: "accounting-transfers-page", webpackPrefetch: true */ 'pages/accounting/transfers'))

export default class AccountingIndexPage extends Component {

  render() {
    const { location: { pathname } } = this.props

    return (
      <div className="Accounting IndexPage row">
        <div className="col-12 text-center">
          <section className='sub-page-wrapper' id='accounting-pages-wrapper'>
            <header>
              <nav className="nav sports-nav nav-tabs justify-content-end">
                <input type="checkbox" id="accounting-page-nav-trigger" className="nav-trigger" />
                <label htmlFor="accounting-page-nav-trigger" className="nav-trigger nav-item nav-link d-md-none">
                  <span><span></span></span>
                  Sub Pages
                </label>
                <Link
                  key={`accounting.pending`}
                  to={`${url}/pending`}
                  className={`nav-item nav-link ${new RegExp(`${url}/pending(_payments)?/?`).test(pathname) ? 'active' : ''}`}
                >
                  Pending
                </Link>
                <Link
                  key={`accounting.billing`}
                  to={`${url}/billing_lookups`}
                  className={`nav-item nav-link ${new RegExp(`${url}/billing_lookups/?`).test(pathname) ? 'active' : ''}`}
                >
                  Info
                </Link>
                <Link
                  key={`accounting.checks`}
                  to={`${url}/checks`}
                  className={`nav-item nav-link ${new RegExp(`/admin/accounting(/checks)?/?$`).test(pathname) ? 'active' : ''}`}
                >
                  Enter Payments
                </Link>
                <Link
                  key={`accounting.refund-requests`}
                  to={`${url}/refund_requests`}
                  className={`nav-item nav-link ${new RegExp(`${url}/refund_requests/?`).test(pathname) ? 'active' : ''}`}
                >
                  Refund Requests
                </Link>
                <Link
                  key={`accounting.remit-forms`}
                  to={`${url}/remit_forms`}
                  className={`nav-item nav-link ${new RegExp(`${url}/remit_forms`).test(pathname) ? 'active' : ''}`}
                >
                  Remit Forms
                </Link>
                <Link
                  key={`accounting.transfers`}
                  to={`${url}/transfers`}
                  className={`nav-item nav-link ${new RegExp(`${url}/transfers`).test(pathname) ? 'active' : ''}`}
                >
                  Transfers
                </Link>
                <Link
                  key={`accounting.users`}
                  to={`${url}/users`}
                  className={`nav-item nav-link ${new RegExp(`${url}/users/?`).test(pathname) ? 'active' : ''}`}
                >
                  Payments By User
                </Link>
              </nav>
            </header>
            <div className="main">
              <Suspense fallback={<JellyBox className="page-loader" />}>
                <Switch>
                  <Route
                    path={`${url}/pending/:id`}
                    component={AccountingPendingPaymentsShowPage}
                  />
                  <Route
                    path={`${url}/pending`}
                    component={AccountingPendingPaymentsIndexPage}
                  />
                  <Route
                    path={`${url}/pending_payments/:id`}
                    component={AccountingPendingPaymentsShowPage}
                  />
                  <Route
                    path={`${url}/pending_payments`}
                    component={AccountingPendingPaymentsIndexPage}
                  />
                  <Route
                    path={`${url}/billing_lookups/:id`}
                    component={AccountingBillingLookupsShowPage}
                  />
                  <Route
                    path={`${url}/billing_lookups`}
                    component={AccountingBillingLookupsIndexPage}
                  />
                  <Route
                    path={`${url}/users`}
                    component={AccountingUsersPage}
                  />
                  <Route
                    path={`${url}/refund_requests/:id`}
                    component={AccountingRefundRequestsShowPage}
                  />
                  <Route
                    path={`${url}/refund_requests`}
                    component={AccountingRefundRequestsIndexPage}
                  />
                  <Route
                    path={`${url}/remit_forms`}
                    component={AccountingRemitFormsPage}
                  />
                  <Route
                    path={`${url}/transfers`}
                    component={AccountingTransfersPage}
                  />
                  <Route component={AccountingDirectPaymentPage} />
                </Switch>
              </Suspense>
            </div>
          </section>
        </div>
      </div>
    );
  }
}
