import React, { Component } from 'react'
import CleanupChannel from 'channels/cleanup'
import AuthStatus from 'common/js/helpers/auth-status'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { DisplayOrLoading } from 'react-component-templates/components';
import { CurrentUser } from 'common/js/contexts/current-user'
import InvitableAthleteForm from 'forms/invitable-athlete-form'


export default class AssignmentsCleanupPage extends Component {
  static contextType = CurrentUser.Context

  version = '0.0.2'

  state = {
    selectedId: null,
    checkingId: null,
    grabBag: [],
    stats: null,
    error: null,
    available: false,
    toggle: false
  }

  get available() {
    return this.state.available
  }

  get channel() {
    return this._channel
  }

  set channel(channel) {
    if(channel !== this._channel) {
      this._channel = channel
      this.forceUpdate()
    }
    return this._channel
  }

  get currentUserId() {
    return this.context.currentUserState.id
  }

  get currentUserIdAsync() {
    return this._loadCurrentUser()
      .then(() => this.currentUserId)
  }

  get timestamp() {
    return Date.now()
  }

  get selectedId() {
    return this.state.selectedId
  }

  get sport() {
    try {
      return (new URLSearchParams(window.location.search)).get("sport")
    } catch(err) {
      return null
    }
  }

  get stats() {
    return Array.isArray(this.state.stats) && this.state.stats
  }

  get toggle() {
    return this.state.toggle
  }

  get wrongVersion() {
    return window.localStorage.getItem('cleanupStorageVersion') !== this.version
  }

  get wrongSport() {
    return window.localStorage.getItem('cleanupSport') !== (this.sport || 'all')
  }

  _closeChannel = () => {
    this.channel && CleanupChannel.closeChannel(this._onMessageReceived)
    this.channel = null
  }

  _onMessageReceived = ({ eventType, data, ...opts}) => {
    switch (eventType) {
      case 'connected':
        return this._loadGrabBag()
      case 'received':
        try {
          const { action } = data
          switch (action) {
            case 'samples':
              this._setGrabBag(data)
              break;
            case 'stats':
              this._setStats(data)
              break;
            case 'availability':
              this._checkAvailability(data)
              break;
            case 'unavailable':
              this._removeId(data)
              break;
            case 'disconnect':
              return this._waitForConnection()
            case 'error':
              return console.log("CHAT ERROR", eventType, data, opts)
            default:
              if(process.env.NODE_ENV === 'development') console.info(eventType, data, opts)
          }
        } catch(err) {
          this._onError(err)
        }
        break;
      case 'disconnected':
        this._waitForConnection()
      //eslint-disable-next-line
      default:
        console.log(eventType, data)
    }
  }

  _onError = (err) => {
    console.error(err)
    this.setState({ error: err.message || err.toString() })
  }

  _getChannel = async () => {
    if(!!AuthStatus.token) {
      if(!AuthStatus.authenticationProven) {
        CleanupChannel.disconnect()
        await AuthStatus.reauthenticate()
      }
      await this._loadCurrentUser()
      this.channel = this.channel || CleanupChannel.openChannel(this._onMessageReceived)
      this.setState({ available: true })
    } else {
      if(this.available) this.setState({ available: false })
    }
  }

  _waitForConnection = () => {
    this._closeChannel()

    this.setState({ available: false }, this._openChannel)
  }

  _checkAvailability = async ({ id, time, user_id }) => {
    if(this.selectedId === id) {
      if(user_id === await this.currentUserIdAsync) return false

      if(time > this.state.selectedTime) {
        this.channel.perform('unavailable', { id })
      } else {
        this._removeId({ id }, this._selectId)
      }
    }
  }

  _checkId = () => {
    const { selectedId, selectedTime = this.timestamp } = this.state
    if(selectedId) {
      this.channel.perform('available', { id: selectedId, time: selectedTime })
    }
  }

  _loadCurrentUser = () =>
    (
      this.context.currentUserState.loaded
      && !this.context.currentUserState.statusChanged
      && this.currentUserId
    )
      ? Promise.resolve()
      : this.context.currentUserActions.getCurrentUser()


  _removeId = async ({ id, user_id }, callback) => {
    if(user_id !== await this.currentUserIdAsync) {
      const cb = callback || (() => {
        if(id === this.selectedId) this._selectId()
      });

      this.setState((state, _) => {
        const grabBag = [ ...state.grabBag ],
              idx     = grabBag.indexOf(id)

        if(idx === -1) return null

        grabBag.splice(idx, 1)

        return { grabBag }
      }, cb)
    }
  }

  _setGrabBag = async (data) => {
    if(data['user_id'] === await this.currentUserIdAsync) {
      this._setStats(data)
      this.setState({ grabBag: data['sample_ids'] || [] }, this._selectId)
    }
  }

  _setStats = (data) =>
    data
    && 'stats' in data
    && this.setState({ stats: data['stats'], toggle: false })

  _selectId = () => {
    if(!this.state.grabBag.length) return this._newGrabBag()

    const selectedId = this.state.grabBag[this.state.grabBag.length * Math.random() | 0],
          selectedTime = this.timestamp

    this.setState({ selectedId, selectedTime }, this._checkId)
  }

  _openChannel = () => {
    AuthStatus.subscribe(this._getChannel)
    this._getChannel()
  }

  _checkCanViewStats = () => this.channel.perform('can_view_stats', {})

  _newGrabBag = () => this.channel.perform('get_samples', { sport: this.sport })

  _toggleOff = () => {
    this.setState({ toggle: true })
    return true
  }

  pullStats = () => this.channel && this._toggleOff() && this.channel.perform('get_stats')

  onSuccess = (transferability) => {
    if(transferability) this._removeId({ id: this.selectedId }, this._selectId)
  }

  _loadGrabBag = async () => {
    try {
      if(this.wrongVersion || this.wrongSport) return this._newGrabBag()
      const inStorage = window.localStorage.getItem('cleanupGrabBagIds'),
            sample_ids = inStorage
              && /^\[[0-9, ]+\]$/.test(inStorage)
              && JSON.parse(inStorage)

      if(!sample_ids || !sample_ids.length) return this._newGrabBag()

      this._setGrabBag({ sample_ids, user_id: await this.currentUserIdAsync })
      this._checkCanViewStats()
    } catch(err) {
      console.error(err)
      return this._newGrabBag()
    }
  }

  _saveGrabBag = () => {
    try {
      window.localStorage.setItem('cleanupGrabBagIds', JSON.stringify(this.state.grabBag || []))
      window.localStorage.setItem('cleanupStorageVersion', this.version)
      window.localStorage.setItem('cleanupSport', this.sport || 'all')
    } catch(err) {
      console.error(err)
    }
  }

  componentDidMount() {
    this._openChannel()
  }

  componentDidUpdate(_, { grabBag }) {
    if(grabBag !== this.state.grabBag) this._saveGrabBag()
  }

  componentWillUnmount() {
    AuthStatus.unsubscribe(this._getChannel)
    this._closeChannel()
  }

  setSport = (ev) => {
    if((this.sport || '') !== ev.currentTarget.value) {
      window.location.href = window.location.pathname
        + (ev.currentTarget.value ? `?sport=${ev.currentTarget.value}` : '')
    }
  }

  render() {
    return (
      <div key="cleanupsLookupWrapper" className="Assignments CleanupsPage row">
        <div className="col">
          <h3 className="text-center pb-3">
            Cleanup Invitations for 2021{this.sport && ` (${this.sport})`}
          </h3>
          <div className="row pb-3">
            <div className="col">
              <label htmlFor="change_sport">
                Choose/Change Sport
              </label>
              <select
                className="form-control"
                name="sport"
                id="change_sport"
                onChange={this.setSport}
                value={this.sport || ''}
              >
                <option value="">All</option>
                <option value="BB">Basketball</option>
                <option value="BBB">Boys Basketball</option>
                <option value="GBB">Girls Basketball</option>
                <option value="CH">Cheer</option>
                <option value="XC">Cross Country</option>
                <option value="GF">Golf</option>
                <option value="FB">Football</option>
                <option value="TF">Track and Field</option>
                <option value="VB">Volleyball</option>
              </select>
            </div>
            <div className="col">
              {
                this.stats && (
                  <div className="pt-3">
                    <h5>
                      <div className="row">
                        <div className="col">
                          Completion Stats
                        </div>
                        <div className="col-auto">
                          <i className="ml-3 material-icons clickable" onClick={this.pullStats}>
                            refresh
                          </i>
                        </div>
                      </div>
                    </h5>
                    <DisplayOrLoading
                      display={!this.toggle}
                      message="UPDATING STATS..."
                      loadingElement={
                        <JellyBox />
                      }
                    >
                      <table className="table">
                        <thead>
                          <tr>
                            <th>
                              Sport
                            </th>
                            <th>
                              Undecided
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          {
                            !this.stats.length && (
                              <tr>
                                <th colSpan="2" className="text-center">
                                  (Click Refresh to Load)
                                </th>
                              </tr>
                            )
                          }
                          {
                            this.stats
                              .map(([ sport, count ], i) => (
                                <tr key={`${sport}.${i}`}>
                                  <th>
                                    { sport }
                                  </th>
                                  <td>
                                    { Number(count || 0).toLocaleString() }
                                  </td>
                                </tr>
                              ))
                          }
                        </tbody>
                      </table>
                    </DisplayOrLoading>
                  </div>
                )
              }
            </div>
          </div>

          <DisplayOrLoading
            display={this.available && !!this.selectedId && this.context.currentUserState.loaded}
            message={(this.available && this.channel) ? 'LOADING...' : 'CONNECTING...'}
            loadingElement={
              <JellyBox className="page-loader" />
            }
          >
            <InvitableAthleteForm
              key={this.selectedId || 'none'}
              id={this.selectedId}
              onSuccess={this.onSuccess}
            />
          </DisplayOrLoading>
        </div>
      </div>
    );
  }
}