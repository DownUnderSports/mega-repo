import React          from 'react';
import AsyncComponent from 'common/js/components/component/async'
import ReactJsonView  from 'react-json-view'
import { DisplayOrLoading, Link }       from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

const accountingRefundRequestsUrl = '/admin/accounting/refund_requests'

export default class AccountingRefundRequestsShowPage extends AsyncComponent {
  constructor(props) {
    super(props)
    this.state = { refund_request: {}, loading: true }
  }

  mainKey = () => ((this.props.match && this.props.match.params) || {}).id
  resultKey = () => 'refund_request'
  url = (id) => `${accountingRefundRequestsUrl}/${id}.json`
  defaultValue = () => ({})

  afterFetch = ({refund_request, skipTime = false}) => this.setStateAsync({
    loading: false,
    refund_request: refund_request || {},
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  deleteRequest = async (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    try {
      await this.setStateAsync({ errors: null, loading: true })

      const result = await fetch(this.url(this.mainKey()), {
        method: 'DELETE',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        }
      });

      result && await result.json()

      await this.setStateAsync({ submitted: true })

      setTimeout(() => this.props.history.push(accountingRefundRequestsUrl), 2000)

    } catch(err) {
      try {
        this.setState({ errors: (await err.response.json()).errors, loading: false })
      } catch(e) {
        this.setState({ errors: [ err.toString() ], loading: false })
      }
    }
  }

  render() {

    if(this.state.submitted) {
      return <section>
        <header>
          <h3 className="mt-3 alert alert-success" role="alert">
            Request Successfully Submitted!
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
        <div className="Accounting RefundRequests ShowPage">
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
            to={this.state.refund_request.link || '#'}
            target='user'
            className="btn btn-block btn-info form-group"
          >
            View User
          </Link>
          <div className="rounded bg-dark p-3 mb-3">
            <ReactJsonView
              src={this.state.refund_request}
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
          <button
            className="btn btn-block btn-danger form-group"
            type="button"
            onClick={this.deleteRequest}
            disabled={!!this.state.loading}
          >
            Delete Request (Completed or Invalid)
          </button>
        </div>
      </DisplayOrLoading>
    );
  }
}
