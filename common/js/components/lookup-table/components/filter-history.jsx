import React, { Component } from 'react'
import ReactJsonView from 'react-json-view'

export default class FilterHistory extends Component {
  state = { open: false }

  get parent() {
    return this.props.parent || {}
  }

  toggleHistory = () => this.setState({open: !this.state.open})

  setHistory = ({ src = {} }) => {
    if(!Object.isPureObject(src)) return false

    const { newState = {} } = this.parent.getCleanState()

    this.parent.setState({...newState, ...src}, this.parent.getRecords)
  }

  render() {
    return this.state.open ? (
      <div className="modal fade show d-block" tabIndex="-1" role="dialog">
        <div className="modal-dialog" role="document">
          <div className="modal-content">
            <div className="modal-header">
              <h5 className="modal-title">Filter History</h5>
              <button type="button" className="close" onClick={this.toggleHistory} aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div className="modal-body" style={{maxHeight: '75vh', overflow: 'scroll'}}>
              {
                this.parent.storageHistory.map((v, i) => (
                  <div key={i} className="row">
                    <div className="col-12 mb-3">
                      <div className="rounded bg-dark p-3">
                        <ReactJsonView
                          src={v}
                          name={false}
                          iconStyle='square'
                          collapsed={0}
                          enableClipboard={this.setHistory}
                          displayObjectSize={true}
                          displayDataTypes={false}
                          sortKeys
                          theme='chalk'
                          className='rounded'
                          style={{backgroundColor: 'none'}}
                        />
                      </div>
                    </div>
                  </div>
                ))
              }
            </div>
            <div className="modal-footer">
              <button
                type="button"
                className="btn btn-danger"
                onClick={this.toggleHistory}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    ) : (
      <div className="col-auto">
        <button
          type="button"
          className="btn btn-light border"
          onClick={this.toggleHistory}
        >
          Show Filter History
        </button>
      </div>
    )
  }
}
