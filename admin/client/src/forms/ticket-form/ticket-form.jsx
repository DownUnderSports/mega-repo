import React                      from 'react'
import Component                  from 'common/js/components/component'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { TextField }              from 'react-component-templates/form-components';
import SortableTable              from 'common/js/components/sortable-table'

const tableHeaders = [
        'team_name',
        'dus_id',
        'has_passport',
        'given_names',
        'surname',
        'category',
        'total_paid',
        'balance',
        'ticket_count',
        'status',
        'required',
        'ticketed',
        'ticket_number',
        'remove'
      ],
      headerAliases = {
        dus_id:       'DUS ID',
        required:     'Keep Schedule?',
        team_name:    'Team',
        ticketed:     'Ticketed?',
        ticket_count: '# of Schedules'
      }

export default class TicketForm extends Component {
  constructor(props) {
    super(props)

    this.state = {
      loading: false,
      errors: null,
      changed: false,
      dusId: '',
      tickets: []
    }

    this.action = `${
      this.props.url
      || `/admin/traveling/flights/schedules/${this.props.scheduleId}/tickets`
    }`
  }

  async componentDidMount() {
    await this.getTickets()
  }

  createTicket = (ev) => {
    this.submitValue(ev, async () => {
      let dus_id = (this.state.dusId || '').replace(/[^A-Za-z]/g, '')

      if(dus_id.length !== 6) throw new Error('Invalid DUS ID');

      return await fetch(this.action, {
        method: 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ dus_id })
      });
    })
  }

  getTickets = async () => {
    try {
      await this.setStateAsync({ loading: true })
      let tickets = await this.fetchResource(
        this.action,
        { timeout: 5000 },
        'tickets',
        []
      )
      console.log(tickets)
      await this.setStateAsync({ tickets })

    } catch(_) {}

    await this.setStateAsync({ loading: false })
  }

  onDusIdChange = (ev) => {
    this.setState({ dusId: ev.currentTarget.value })
  }

  onKeyDown = ev => {
    if(ev.key === "Enter") {
      ev.preventDefault()
      ev.stopPropagation()
      this.setTicketNumber(ev)
    }
  }

  setTicketNumber = (ev) => {
    this.submitValue(ev, async () => {
      const id       = String(ev.currentTarget.dataset.id || ''),
            original = String(ev.currentTarget.dataset.original || ''),
            value    = String(ev.currentTarget.value)

      if(!value && !original) return false

      if(!id) throw new Error('Invalid Record');

      return await fetch(`${this.action}/${id}`, {
        method: 'PATCH',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ ticketed: !!value, ticket_number: value })
      });
    })
  }

  submitValue = async (ev, func) => {
    ev.preventDefault()
    ev.stopPropagation()
    try {
      this.setState({ errors: null })

      const result = await func()

      result && await result.json()

    } catch(err) {
      try {
        this.setState({ errors: (await err.response.json()).errors })
      } catch(e) {
        this.setState({ errors: [ err.message ] })
      }
    }
    await this.getTickets()
  }

  removeTicket = (ev) => {
    this.submitValue(ev, async () => {
      const id       = String(ev.currentTarget.dataset.id || '')

      if(!id) throw new Error('Invalid Record');

      return await fetch(`${this.action}/${id}`, {
        method: 'DELETE',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        }
      });
    })
  }

  toggleRequired = (ev) => {
    this.submitValue(ev, async () => {
      const id       = String(ev.currentTarget.dataset.id || ''),
            original = Number(ev.currentTarget.dataset.original || 0)

      if(!id) throw new Error('Invalid Record');

      return await fetch(`${this.action}/${id}`, {
        method: 'PATCH',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ required: !original })
      });
    })
  }

  ticketsData = () => (this.state.tickets || []).map((row, i) => ({
    ...row,
    has_passport:   row.has_passport ? 'Yes' : 'No',
    ticketed:       row.ticketed ? 'Yes' : 'No',
    required:       (
                      <Link
                        to="#"
                        data-id={row.id}
                        data-original={row.required ? 1 : 0}
                        onClick={this.toggleRequired}
                      >
                        {row.required ? 'Yes' : 'No'}
                      </Link>
                    ),
    ticket_number:  (
                      <TextField
                        data-id={row.id}
                        data-original={row.ticket_number || ''}
                        onBlur={this.setTicketNumber}
                        defaultValue={row.ticket_number || ''}
                        onKeyDown={this.onKeyDown}
                      />
                    ),
    remove:         (
                      <Link
                        to="#"
                        data-id={row.id}
                        onClick={this.removeTicket}
                      >
                        Delete Ticket?
                      </Link>
                    )
  }))

  render(){
    return (
      <section>
        <div className='main m-0'>
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
          <DisplayOrLoading display={!this.state.loading}>
            <div className="row">
              <div className="col-12">
                <SortableTable
                  headers={tableHeaders}
                  data={this.ticketsData()}
                  headerAliases={headerAliases}
                >
                  <div className="row">
                    <div className="col-lg-6 was-validated">
                      <TextField
                        name="flight_schedule[create_ticket_dus_id]"
                        id="flight_schedule_create_ticket_dus_id"
                        value={this.state.dusId || ''}
                        onChange={this.onDusIdChange}
                        label="Enter DUS ID to add a new traveler to PNR"
                        className="form-control form-group"
                        pattern="[A-Za-z]{3}-?[A-Za-z]{3}"
                      />
                      <button
                        type="button"
                        className="btn btn-block btn-info"
                        disabled={!this.state.dusId || (this.state.dusId.length < 6)}
                        onClick={this.createTicket}
                      >
                        Add Traveler to {this.props.schedulePNR}
                      </button>
                    </div>
                  </div>
                </SortableTable>
              </div>
            </div>
          </DisplayOrLoading>
        </div>
      </section>
    )
  }
}
