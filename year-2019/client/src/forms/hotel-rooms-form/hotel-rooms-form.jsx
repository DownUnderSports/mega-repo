import React                      from 'react'
import Component                  from 'common/js/components/component'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { TextField }              from 'react-component-templates/form-components';
import SortableTable              from 'common/js/components/sortable-table'
import Confirmation               from 'common/js/forms/components/confirmation'

const tableHeaders = [
        'team_name',
        'dus_id',
        'given_names',
        'surname',
        'category',
        'total_rooms',
        'status',
        'arriving',
        'departing',
        'check_in_date',
        'check_out_date',
        'number',
        'edit',
        'remove'
      ],
      headerAliases = {
        check_in_date:  'Check In',
        check_out_date: 'Check Out',
        dus_id:         'DUS ID',
        team_name:      'Team',
      }

export default class HotelRoomForm extends Component {
  constructor(props) {
    super(props)

    this.state = {
      loading:  false,
      errors:   null,
      changed:  false,
      editing:  false,
      dusId:    '',
      checkIn:  '',
      checkOut: '',
      rooms:    []
    }

    this.action = `${
      this.props.url
      || `/admin/traveling/ground_control/hotels/${this.props.hotelId}/rooms`
    }`
  }

  async componentDidMount() {
    await this.getHotelRooms()
  }

  createHotelRoom = (ev) => {
    this.submitValue(ev, async () => {
      const dus_id = (this.state.dusId || '').replace(/[^A-Za-z]/g, ''),
            check_in_date = this.state.checkIn,
            check_out_date = this.state.checkOut

      if(dus_id.length !== 6) throw new Error('Invalid DUS ID');

      if(!Date.parse(check_in_date)) throw new Error('Invalid Check In Date')

      if(!Date.parse(check_out_date)) throw new Error('Invalid Check Out Date')

      if(Date.parse(check_out_date) <= Date.parse(check_in_date)) throw new Error("Can't check out before checking in")

      return await fetch(this.action, {
        method: 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ check_in_date, check_out_date, dus_id })
      });
    })
  }

  getHotelRooms = async () => {
    try {
      await this.setStateAsync({ loading: true })
      let rooms = await this.fetchResource(
        this.action,
        { timeout: 5000 },
        'rooms',
        []
      )
      console.log(rooms)
      await this.setStateAsync({ rooms })

    } catch(_) {}

    await this.setStateAsync({ loading: false })
  }

  onDusIdChange = (ev) => {
    this.addChange('dusId', ev)
  }

  onCheckInChange = (ev) => {
    this.addChange('checkIn', ev)
  }

  onCheckOutChange = (ev) => {
    this.addChange('checkOut', ev)
  }

  addChange = (k, ev) => {
    this.setState({ [k]: ev.currentTarget.value })
  }

  onEditNumber = (ev) => {
    this.onEdit('number', ev)
  }

  onEditCheckIn = (ev) => {
    this.onEdit('check_in_date', ev)
  }

  onEditCheckOut = (ev) => {
    this.onEdit('check_out_date', ev)
  }

  onEdit = (k, ev) => {
    this.setState({ editing: { ...this.state.editing, [k]: ev.currentTarget.value } })
  }

  onEditKeyDown = ev => {
    if(ev.key === "Enter") {
      ev.preventDefault()
      ev.stopPropagation()
    }
  }

  editRoom = (ev) => {
    for(let i = 0; i < this.state.rooms.length; i++) {
      const editing = this.state.rooms[i]

      if(Number(editing.id) === Number(ev.currentTarget.dataset.id)) {
        return this.setState({ editing })
      }
    }
  }

  submitEdits = (ev) => {
    this.submitValue(ev, async () => {
      const { id, number, check_in_date, check_out_date } = this.state.editing,
            room = { number, check_in_date, check_out_date }

      if(!id) throw new Error('Invalid Record');

      let original

      for(let i = 0; i < this.state.rooms.length; i++) {
        original = this.state.rooms[i]

        if(Number(original.id) === Number(id)) break;
      }

      if(
        (original.number === room.number)
        && (original.check_in_date === room.check_in_date)
        && (original.check_out_date === room.check_out_date)
      ) throw new Error('No Changes Made')

      return await fetch(`${this.action}/${id}`, {
        method: 'PATCH',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ room })
      });
    })
  }

  cancelEdits = (ev) => {
    this.setState({ editing: false })
  }

  setHotelRoomNumber = (ev) => {

  }

  submitValue = async (ev, func) => {
    ev.preventDefault()
    ev.stopPropagation()
    try {
      this.setState({ errors: null })

      const result = await func()

      result && await result.json()

      this.setState({ dusId: '', checkIn: '', checkOut: '', editing: false })

    } catch(err) {
      try {
        this.setState({ errors: (await err.response.json()).errors })
      } catch(e) {
        this.setState({ errors: [ err.message ] })
      }
    }
    await this.getHotelRooms()
  }

  removeHotelRoom = (ev) => {
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

  roomsData = () => (this.state.rooms || []).map((row, i) => ({
    ...row,
    edit:   (
              <Link
                to="#"
                data-id={row.id}
                onClick={this.editRoom}
              >
                Edit
              </Link>
            ),
    remove: (
              <Link
                to="#"
                data-id={row.id}
                onClick={this.removeHotelRoom}
              >
                Delete Room?
              </Link>
            )
  }))

  render(){
    console.log(this.state.editing)
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
              <div className="col">
                {
                  this.state.editing && (
                    <Confirmation
                      onConfirm={this.submitEdits}
                      onCancel={this.cancelEdits}
                    >
                      <div className="row">
                        <div className="col-12">
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
                        <div className="col was-validated">
                          <TextField
                            name="traveler_hotel[create_room_dus_id]"
                            id="traveler_hotel_create_room_dus_id"
                            value={this.state.editing.number || ''}
                            onChange={this.onEditNumber}
                            label="Enter Room Number (optional)"
                            className="form-control form-group"
                            onKeyDown={this.onEditKeyDown}
                          />
                          <TextField
                            type="date"
                            name="traveler_hotel[create_room_check_in_date]"
                            id="traveler_hotel_create_room_check_in_date"
                            value={this.state.editing.check_in_date || ''}
                            onChange={this.onEditCheckIn}
                            label="Edit Check In Date"
                            className="form-control form-group"
                            pattern="[0-9]{4}-[0-9]{2}-[0-9]{2}"
                            onKeyDown={this.onEditKeyDown}
                          />
                          <TextField
                            type="date"
                            name="traveler_hotel[create_room_check_out_date]"
                            id="traveler_hotel_create_room_check_out_date"
                            value={this.state.editing.check_out_date || ''}
                            onChange={this.onEditCheckOut}
                            label="Edit Check Out Date"
                            className="form-control form-group"
                            pattern="[0-9]{4}-[0-9]{2}-[0-9]{2}"
                            onKeyDown={this.onEditKeyDown}
                          />
                        </div>
                      </div>
                    </Confirmation>
                  )
                }
              </div>
            </div>
            <div className="row">
              <div className="col-12">
                <SortableTable
                  headers={tableHeaders}
                  data={this.roomsData()}
                  headerAliases={headerAliases}
                >
                  <div className="row">
                    <div className="col-lg-6 was-validated">
                      <TextField
                        name="traveler_hotel[create_room_dus_id]"
                        id="traveler_hotel_create_room_dus_id"
                        value={this.state.dusId || ''}
                        onChange={this.onDusIdChange}
                        label="Enter DUS ID"
                        className="form-control form-group"
                        pattern="[A-Za-z]{3}-?[A-Za-z]{3}"
                      />
                      <TextField
                        type="date"
                        name="traveler_hotel[create_room_check_in_date]"
                        id="traveler_hotel_create_room_check_in_date"
                        value={this.state.checkIn || ''}
                        onChange={this.onCheckInChange}
                        label="Enter Check In Date"
                        className="form-control form-group"
                        pattern="[0-9]{4}-[0-9]{2}-[0-9]{2}"
                      />
                      <TextField
                      type="date"
                        name="traveler_hotel[create_room_check_out_date]"
                        id="traveler_hotel_create_room_check_out_date"
                        value={this.state.checkOut || ''}
                        onChange={this.onCheckOutChange}
                        label="Enter Check Out Date"
                        className="form-control form-group"
                        pattern="[0-9]{4}-[0-9]{2}-[0-9]{2}"
                      />
                      <button
                        type="button"
                        className="btn btn-block btn-info"
                        disabled={
                          !this.state.dusId
                          || (this.state.dusId.length < 6)
                          || !this.state.checkIn
                          || (this.state.checkIn.length !== 10)
                          || !this.state.checkOut
                          || (this.state.checkOut.length !== 10)
                        }
                        onClick={this.createHotelRoom}
                      >
                        Add Traveler to Room in { this.props.buttonText }
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
