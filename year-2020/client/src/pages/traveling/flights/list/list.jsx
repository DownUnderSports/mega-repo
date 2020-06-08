import React from 'react'
import AsyncComponent from 'common/js/components/component/async'
import ReactJsonView from 'react-json-view'
import FileDownload from 'common/js/components/file-download'
import { DisplayOrLoading } from 'react-component-templates/components';

export default class FlightsIndexPage extends AsyncComponent {
  state = { flights: {}, loaded: false, failed: false }

  async componentDidMount() {
    await this.fetchFlights()
  }

  componentWillUnmount() {
    this.abortFetch()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  fetchFlights = async (ev) => {
    if(ev) {
      try {
        ev.preventDefault()
        ev.stopPropagation()
      } catch(_) {}
    }

    try {
      await this.setStateAsync({ flights: {}, loaded: false, failed: false })
      this.abortFetch()
      this._fetchable = fetch('/admin/traveling/flights.json', {
        method: 'GET',
        timeout: 30000
      })
      const response = await this._fetchable,
      flights = await response.json()
      await this.setStateAsync({ flights, loaded: true })
    } catch(e) {
      await this.setStateAsync({ loaded: true, flights: {}, failed: true })
    }
  }

  render() {
    return (
      <section className='IndexPage'>
        <header className="container-fluid border-bottom py-3 bg-light">
          <h3>Current Flights</h3>
        </header>
        <div className="main container rounded p-3 mt-5">
          <div className="row mb-5">
            <div className="col">
              <FileDownload path='/admin/traveling/flights.csv'>
                <span className="btn btn-block clickable btn-info">
                  Click Here To Download CSV
                </span>
              </FileDownload>
            </div>
          </div>
          <hr />
          <div className="row">
            <div className="col">
              <DisplayOrLoading display={this.state.loaded}>
                {
                  this.state.failed || (
                    <div className="rounded bg-dark p-3 mb-3">
                      <ReactJsonView
                        src={this.state.flights}
                        name={false}
                        iconStyle='square'
                        collapsed={1}
                        enableClipboard={false}
                        displayObjectSize={false}
                        displayDataTypes={false}
                        sortKeys
                        theme='chalk'
                        className='rounded'
                        style={{backgroundColor: 'none'}}
                      />
                    </div>
                  )
                }
                <button
                  className="btn btn-block btn-warning"
                  onClick={this.fetchFlights}
                >
                  { this.state.failed ? 'Loading Failed, Click here to Retry' : 'Reload' }
                </button>
              </DisplayOrLoading>

            </div>

          </div>
        </div>
      </section>

    )
  }
}
