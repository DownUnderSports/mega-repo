import React           from 'react';
import AsyncComponent  from 'common/js/components/component/async'
import FileDownload    from 'common/js/components/file-download'
import LookupTable     from 'common/js/components/lookup-table'
import CalendarField   from 'common/js/forms/components/calendar-field'
import Confirmation from 'common/js/forms/components/confirmation';
import { DisplayOrLoading } from 'react-component-templates/components';

const eventRegistrationsUrl = '/admin/traveling/event_registrations',
      headers = [
        'team_name',
        'dus_id',
        'departing_date',
        'first',
        'middle',
        'last',
        'total_events',
        '100 M Relay?',
        '400 M Relay?',
      ],
      aliasFields = {
        '100 M Relay?': 'has_one_hundred_m_relay',
        '400 M Relay?': 'has_four_hundred_m_relay',
      },
      copyFields = [
        'dus_id'
      ],
      tableStyle = {
        minWidth: '50vw'
      }

export default class TravelingEventRegistrationsPage extends AsyncComponent {
  filterComponent = (h, v, onChange, defaultComponent) =>
    /_date/.test(h) ? (
      <div className="row text-dark">
        <div className='col'>
          <CalendarField
            measurable
            closeOnSelect
            skipExtras
            className='form-control'
            name={h}
            type='text'
            pattern={"\\d{4}-\\d{2}-\\d{2}"}
            onChange={(e, o) => onChange(h, o.value)}
            value={v}
          />
        </div>
      </div>
    ) : (
      /has_|\?/.test(h) ? (
        <select
          className='form-control'
          onChange={(ev) => onChange(h, ev.target.value)}
          value={v}
        >
          <option value=""></option>
          <option value="TRUE">Yes</option>
          <option value="FALSE">No</option>
        </select>
      ) : defaultComponent(h, v)
    )

  renderButtons = () => (
    <div className="row">
      <div className="col-auto form-group">
        <FileDownload key="xlsxDownload" path={`${eventRegistrationsUrl}.csv`}>
          <span key="xlsxDownloadButton" className="btn btn-primary clickable btn-info">
            Full List
          </span>
        </FileDownload>
      </div>
      <div className='col'></div>
    </div>
  )

  rowClassName(u){
    return 'clickable'
  }

  getDetails = async ({ id, url }) => {
    console.log(id, url)
    this.setState({
      showEvent: {
        title: 'LOADING...'
      }
    })

    const result = await this.fetchResource(url, this.fetchOptions())

    delete result.events.full

    const events = []

    for (let event in result.events) {
      events.push({ event, ...result.events[event] })
    }
    for (let event in result.relays) {
      events.push({ event: String(event || '').replace(/4 x/i, ''), ages: [ '✔' ], time: result.relays[event] })
    }

    console.log(events)

    this.setState({
      showEvent: {
        title: result.title,
        events
      }
    })
  }

  closeDetails = () => this.setState({ showEvent: false })

  render() {
    return (
      <div className="EventRegistrations IndexPage row">
        {
          this.state.showEvent && (
            <div className="col-12">
              <Confirmation
                title={this.state.showEvent.title}
                onConfirm={this.closeDetails}
                onCancel={this.closeDetails}
              >
                <DisplayOrLoading
                  display={!!this.state.showEvent.events}
                >
                  <table className="table" style={tableStyle} >
                    <thead>
                      <tr>
                        <th>
                          Event
                        </th>
                        <th>
                          Age Group(s)
                        </th>
                        <th>
                          Personal Best
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      {
                        this.state.showEvent.events
                        && this.state.showEvent.events.map(({event, ages, time}) => (
                          <tr key={event}>
                            <th>
                              { event }
                            </th>
                            <th>
                              { ages.join(', ') }
                            </th>
                            <th>
                              { time }
                            </th>
                          </tr>
                        ))
                      }
                    </tbody>
                  </table>
                </DisplayOrLoading>
              </Confirmation>
            </div>
          )
        }
        <LookupTable
          onClick={this.getDetails}
          url={eventRegistrationsUrl}
          headers={headers}
          copyFields={copyFields}
          aliasFields={aliasFields}
          initialSearch={true}
          filterComponent={this.filterComponent}
          renderButtons={this.renderButtons}
          rowClassName={this.rowClassName}
          localStorageKey="adminEventRegistrationsIndexState"
          idKey="dus_id"
          resultsKey="event_registrations"
          tabKey="event_registration"
          className="col-12"
        />
      </div>
    );
  }
}
