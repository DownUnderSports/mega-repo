import React, { Component } from 'react'
import CheckInChannel from 'channels/check-in'
import OutboundInternationalFlight from 'models/outbound-international-flight'
import AuthStatus from 'helpers/auth-status'
import { DisplayOrLoading } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import dusIdFormat from 'helpers/dus-id-format'

export default class CheckInForm extends Component {
  state = { birthDate: '', dusId: '', ready: false, failed: false, errors: null, submitting: false }

  _closeChannel = () => {
    this._channel && CheckInChannel.closeChannel(this._onCheckInNotification)
  }

  _getChannel = () => {
    if(AuthStatus.dusId) {
      this._channel = this._channel || CheckInChannel.openChannel(this._onCheckInNotification)
      this.setState({ available: true })
    } else {
      if(this.state.available) this.setState({ available: false })
    }
  }

  _onBirthDateChange = ev => {
    const birthDate = String(ev.currentTarget.value || '')

    if(birthDate !== this.state.birthDate) this.setState({ birthDate, ready: !!birthDate && this.state.dusId.length > 6 })
  }

  _onCheckInNotification = async ({ eventType, data }) => {
    console.log(eventType, data)
    switch (eventType) {
      // case 'connected':
      //   return this._channel.perform('joined')
      case 'received':
        try {
          const { flight, action } = data

          console.log(flight, action)

          switch (action) {
            case 'checked-in':
              return console.log(await OutboundInternationalFlight.saveRecord(flight))
            default:
              if(process.env.NODE_ENV === 'development') console.info(data)
          }
        } catch(err) {
          console.error(err)
          this.setState({ error: err.message || err.toString() })
        }
        break;
      default:
        console.log(eventType, data)
    }
  }

  _onDusIdChange = (ev) => {
    const dusId = dusIdFormat(String(ev.currentTarget.value || ''))

    if(dusId !== this.state.dusId) this.setState({ dusId, failed: false, ready: !!this.state.birthDate && dusId.length > 6})
  }

  _onSubmit = async (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    await new Promise(r => this.setState({ success: false, errors: null, submitting: true }, r))
    try {
      if(!/^[A-Z]{3}-?[A-Z]{3}$/.test(this.state.dusId)) throw new Error('Invalid DUS ID')

      const response = await fetch(
        `/aus/check_in`,
        {
          method: 'POST',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify({ dus_id: this.state.dusId, birth_date: this.state.birthDate })
        }
      )

      await response.json()

      return this.setState({
        success:   this.state.dusId,
        dusId:     '',
        birthDate: '',
        submitting: false,
        ready: false,
      }, this._resetSuccess)
    } catch(err) {
      try {
        const errorResponse = await err.response.json()
        console.log(errorResponse)
        this.setState({errors: errorResponse.errors || [ errorResponse.message ], submitting: false})
      } catch(e) {
        this.setState({errors: [ err.message ], submitting: false})
      }
    }
  }

  _resetSuccess = () => {
    setTimeout(() => {
      this.setState({success: false})
    }, 2000)
  }

  componentDidMount() {
    AuthStatus.subscribe(this._getChannel)
    this._getChannel()
  }

  componentWillUnmount() {
    AuthStatus.unsubscribe(this._getChannel)
    this._closeChannel()
  }

  renderErrors() {
    return (
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
    )
  }

  render() {
    return (
      <DisplayOrLoading display={(AuthStatus.dusId || AuthStatus.token) && !this.state.submitting}>
        {
          this.state.success && <div className="row">
            <div className="col">
              <div className="alert alert-success form-group" role="alert">
                {this.state.success} is Checked In!
              </div>
            </div>
          </div>
        }
        { this.renderErrors() }
        <div className="row">
          <div className="col-md form-group">
            <TextField
              name='dusId'
              label="Traveler DUS ID"
              onChange={this._onDusIdChange}
              value={this.state.dusId || ''}
              caretIgnore='-'
              className='form-control'
              autoComplete='off'
              placeholder='AAA-AAA'
              pattern="[a-zA-Z]*"
              looseCasing
            />
          </div>
          <div className="col-md form-group">
            <TextField
              type="date"
              name='birthDate'
              label="Traveler Birth Date"
              onChange={this._onBirthDateChange}
              value={this.state.birthDate || ''}
              className='form-control'
              autoComplete='off'
              placeholder='2020-06-29'
              pattern="[0-9-\\/]+"
            />
          </div>
          <div className="col-md form-group">
            <label>&nbsp;</label>
            <button
              type="button"
              onClick={this._onSubmit}
              className="btn btn-block btn-primary"
              disabled={!this.state.ready}
            >
              Check In
            </button>
          </div>
        </div>
      </DisplayOrLoading>
    )
  }
}
