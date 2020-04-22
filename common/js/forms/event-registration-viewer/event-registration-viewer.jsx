import React, { Component } from 'react'
import { shape, array, string } from 'prop-types'

export default class EventRegistrationForm extends Component {
  static propTypes = {
    events: shape({
      events: array.isRequired,
      id: string,
      name: string
    }).isRequired
  }

  render() {
    const {events: {events = [], id, name}} = this.props;

    console.log(events)
    return (
      <section>
        <header className='form-group'>
          <h3 className="text-center">
            {name}&apos;s Submitted Event Registration
          </h3>
          <h6 className='text-center'>
           ({id})
          </h6>
        </header>
        <div className="row form-group">
          <div className="col-md-6 form-group">
            <a
              href="/assets/pdfs/track-event-terms.pdf?1.0.2"
              target="_blank"
              rel="noopener noreferrer"
              className="btn btn-primary btn-block"
            >
              Review Track Meet Rules
            </a>
          </div>
          <div className="col-md-6 form-group">
            <a
              href="/assets/pdfs/track-event-timetable.pdf?1.0.2"
              target="_blank"
              rel="noopener noreferrer"
              className="btn btn-primary btn-block"
            >
              Review Event Timetable
            </a>
          </div>
        </div>
        <div className="row form-group">
          <div className="col">
            <table className="table table-bordered table-hover table-sm text-center">
              <thead>
                <tr>
                  <th scope="col">
                    #
                  </th>
                  <th scope='col'>
                    Event
                  </th>
                  <th scope='col'>
                    Age Group
                  </th>
                  <th scope='col'>
                    Best
                  </th>
                </tr>
              </thead>
              <tbody>
                {
                  events.map((data, i) => (<tr key={i}>
                    <th scope="row">
                      {i + 1}
                    </th>
                    <td>
                      {data.event}
                    </td>
                    <td>
                      {data.age || (<span>&#10004;</span>)}
                    </td>
                    <td>
                      {data.best}
                    </td>
                  </tr>))
                }
              </tbody>
            </table>
          </div>
        </div>
      </section>
    )
  }
}
