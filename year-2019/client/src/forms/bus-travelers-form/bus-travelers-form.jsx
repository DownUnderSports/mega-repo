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
        'status',
        'arriving',
        'departing',
        'remove',
      ],
      headerAliases = {
        dus_id:    'DUS ID',
        team_name: 'Team',
      }

export default class BusTravelersForm extends Component {
  constructor(props) {
    super(props)

    this.state = {
      loading: false,
      errors: null,
      changed: false,
      dusId: '',
      travelers: []
    }

    this.action = `${
      this.props.url
      || `/admin/traveling/ground_control/buses/${this.props.busId}/bus_travelers`
    }`
  }

  async componentDidMount() {
    await this.getTravelers()
  }

  createTraveler = (ev) => {
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

  getTravelers = async () => {
    try {
      await this.setStateAsync({ loading: true })
      let travelers = await this.fetchResource(
        this.action,
        { timeout: 5000 },
        'travelers',
        []
      )
      console.log(travelers)
      await this.setStateAsync({ travelers })

    } catch(_) {}

    await this.setStateAsync({ loading: false })
  }

  onDusIdChange = (ev) => {
    this.setState({ dusId: ev.currentTarget.value })
  }

  submitValue = async (ev, func) => {
    ev.preventDefault()
    ev.stopPropagation()
    try {
      this.setState({ errors: null })

      const result = await func()

      result && await result.json()

      this.setState({ dusId: '' })

    } catch(err) {
      try {
        this.setState({ errors: (await err.response.json()).errors })
      } catch(e) {
        this.setState({ errors: [ err.message ] })
      }
    }
    await this.getTravelers()
  }

  removeTraveler = (ev) => {
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

  travelersData = () => (this.state.travelers || []).map((row, i) => ({
    ...row,
    has_passport:   row.has_passport ? 'Yes' : 'No',
    remove:         (
                      <Link
                        to="#"
                        data-id={row.id}
                        onClick={this.removeTraveler}
                      >
                        Delete Traveler?
                      </Link>
                    )
  }))

  label = "Enter DUS ID to add a new traveler to Bus"

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
                  data={this.travelersData()}
                  headerAliases={headerAliases}
                >
                  <div className="row">
                    <div className="col-lg-6 was-validated">
                      <TextField
                        name="flight_schedule[create_ticket_dus_id]"
                        id="flight_schedule_create_ticket_dus_id"
                        value={this.state.dusId || ''}
                        onChange={this.onDusIdChange}
                        label={this.label}
                        className="form-control form-group"
                        pattern="[A-Za-z]{3}-?[A-Za-z]{3}"
                      />
                      <button
                        type="button"
                        className="btn btn-block btn-info"
                        disabled={!this.state.dusId || (this.state.dusId.length < 6)}
                        onClick={this.createTraveler}
                      >
                        Add Traveler to {this.props.buttonText}
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
