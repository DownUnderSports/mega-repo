import React, { Component } from 'react'
import FetchQueue from 'common/js/helpers/fetch-queue'
import dateFns from 'date-fns'

const timeFormat = 'HH:mm:ss'

class QueueViewer extends Component {
  render() {
    return (
      <div className="row">
        <div className="col-12 my-3">
          <div className="bg-secondary rounded p-3">
            <h3>
              Running:
              <button className='btn float-right btn-primary' onClick={this.props.hide}>
                Hide
              </button>
            </h3>
            <table className="table">
              <tbody>
                <tr>
                  <th>
                    {this.props.count}
                  </th>
                  <td>
                    {
                      Object.keys(this.props.running).map((k) => (
                        <span key={`running.${k}`}>{k};</span>
                      ))
                    }
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <div className="col-12 my-3">
          <div className="bg-secondary rounded p-3">
            <h3>
              Queued:
            </h3>
            <table className="table">
              <thead>
                <tr>
                  <th>
                    Queued At
                  </th>
                  <th>
                    Url
                  </th>
                  <th>
                    Canceled
                  </th>
                </tr>
              </thead>
              <tbody>
                {
                  this.props.queue.map((i) => (
                    <tr key={`queued.${i.key}`}>
                      <td>
                        {dateFns.format(i.queuedAt, timeFormat)}
                      </td>
                      <td>
                        {i.url}
                      </td>
                      <td>
                        {i.canceled ? 'Yes' : 'No'}
                      </td>
                    </tr>
                  ))
                }
              </tbody>
            </table>
          </div>
        </div>
        <div className="col-12 my-3">
          <div className="bg-secondary rounded p-3">
            <h3>
              History:
            </h3>
            <table className="table">
              <thead>
                <tr>
                  <th>
                    Queued At
                  </th>
                  <th>
                    Ran At
                  </th>
                  <th>
                    Completed At
                  </th>
                  <th>
                    Canceled
                  </th>
                  <th>
                    Url
                  </th>
                </tr>
              </thead>
              <tbody>
                {
                  this.props.ran.map((i) => (
                    <tr key={`ran.${i.key}`}>
                      <th>
                        {dateFns.format(i.queuedAt, timeFormat)}
                      </th>
                      <th>
                        {dateFns.format(i.ranAt, timeFormat)}
                      </th>
                      <th>
                        {dateFns.format(i.completedAt, timeFormat)}
                      </th>
                      <th>
                        {i.canceled ? 'Yes' : 'No'}
                      </th>
                      <th>
                        {i.url}
                      </th>
                    </tr>
                  ))
                }
              </tbody>
            </table>
          </div>
        </div>
      </div>
    )
  }
}

export default class QueueTracker extends Component {
  state = { visible: false }

  componentDidMount() {
    if(localStorage.getItem('ShowQueueTracker')) this.setVisible()
    window.document.addEventListener('openQueueViewer', this.setVisible)
  }

  componentWillUnmount() {
    window.document.removeEventListener('openQueueViewer', this.setVisible)
    window.document.removeEventListener('closeQueueViewer', this.setInvisible)
    window.document.removeEventListener('fetchQueueUpdate', this.runForcedUpdate)
  }

  setVisible = () => {
    if(!this.state.visible) {
      window.document.addEventListener('closeQueueViewer', this.setInvisible)
      window.document.addEventListener('fetchQueueUpdate', this.runForcedUpdate)
      this.setState({visible: true})
    }
  }

  setInvisible = () => {
    if(this.state.visible) {
      window.document.removeEventListener('closeQueueViewer', this.setInvisible)
      window.document.removeEventListener('fetchQueueUpdate', this.runForcedUpdate)
      this.setState({visible: false})
    }
  }

  runForcedUpdate = () => this.forceUpdate()

  render() {
    return (
      <div
        className={`bg-dark border text-white ${this.state.visible ? 'd-block' : 'd-none'}`}
        style={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          width: '100vw',
          height: '50vh',
          overflow: 'auto',
          zIndex: 5000
        }}
      >
        <div className="container-fluid py-3">
          {
            this.state.visible && (
              <QueueViewer
                queue={FetchQueue.queue}
                running={FetchQueue.running}
                ran={FetchQueue.ran}
                count={FetchQueue.runningCount}
                hide={this.setInvisible}
              />
            )
          }
        </div>
      </div>
    )
  }
}
