import React          from 'react';
import AsyncComponent from 'common/js/components/component/async'
import ReactJsonView  from 'react-json-view'
import { DisplayOrLoading, Link }       from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

const accountingBillingLookupsUrl = '/admin/accounting/billing_lookups'

export default class AccountingBillingLookupsShowPage extends AsyncComponent {
  constructor(props) {
    super(props)
    this.state = { payment: {}, loading: true }
  }

  mainKey = () => ((this.props.match && this.props.match.params) || {}).id
  resultKey = () => 'payment'
  url = (id) => `${accountingBillingLookupsUrl}/${id}.json`
  defaultValue = () => ({})

  afterFetch = ({payment, skipTime = false}) => this.setStateAsync({
    loading: false,
    payment: payment || {},
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  render() {

    if(this.state.submitted) {
      return <section>
        <header>
          <h3 className="mt-3 alert alert-success" role="alert">
            Decision Entered!
          </h3>
        </header>
        <p>
          You will be redirected shortly...
        </p>
      </section>
    }

    return (
      <DisplayOrLoading
        display={!this.state.loading}
        loadingElement={
          <JellyBox className="page-loader" />
        }
      >
        <div className="Accounting BillingLookups ShowPage">
          {
            <div className="row">
              <div className="col">
                {
                  this.state.errors && <div className="alert alert-danger form-group" role="alert">
                    {
                      this.state.errors.map((v, k) => (
                        <div className='row' key={k}>
                          <div className="col">
                            { v }
                          </div>
                        </div>
                      ))
                    }
                  </div>
                }
              </div>
            </div>
          }
          <Link
            to={this.state.payment.link || '#'}
            target='user'
            className="btn btn-block btn-info form-group"
          >
            View User
          </Link>
          <div className="rounded bg-dark p-3 mb-3">
            <ReactJsonView
              src={this.state.payment}
              name={false}
              iconStyle='square'
              enableClipboard={false}
              displayObjectSize={false}
              displayDataTypes={false}
              theme='chalk'
              className='rounded'
              style={{backgroundColor: 'none'}}
            />
          </div>
        </div>
      </DisplayOrLoading>
    );
  }
}
