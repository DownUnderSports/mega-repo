import React, {createContext, Component} from 'react'
import CoachLocationChannel from 'channels/coach-location'
import AuthStatus from 'helpers/auth-status'
import MapGL, { GeolocateControl, NavigationControl } from 'react-map-gl';
import ScatterplotOverlay from './overlays/scatterplot'
import throttle from 'helpers/throttle'
import 'mapbox-gl/dist/mapbox-gl.css';

const geolocateStyle = {
  position: 'absolute',
  top: 0,
  left: 0,
  margin: 10
};

const airports = {
  LAX: {
    altitude: 1.5,
    bearing: 0,
    height: 648,
    latitude: 33.94570648805298,
    longitude: -118.40410049702403,
    maxPitch: 0,
    maxZoom: 24,
    minPitch: 0,
    minZoom: 0,
    pitch: 0,
    zoom: 13.5,
    width: 1080,
  },
  YVR: {
    altitude: 1.5,
    bearing: 0,
    height: 648,
    latitude: 49.19407213859564,
    longitude: -123.18293461791089,
    maxPitch: 0,
    maxZoom: 24,
    minPitch: 0,
    minZoom: 0,
    pitch: 0,
    zoom: 13.5,
    width: 1080,
  },
  YYZ: {
    altitude: 1.5,
    bearing: 0,
    height: 648,
    latitude: 43.676291911469384,
    longitude: -79.63377976537414,
    maxPitch: 0,
    maxZoom: 24,
    minPitch: 0,
    minZoom: 0,
    pitch: 0,
    zoom: 12.835520843283167,
    width: 1080,
  }
}

export const Map = {}

Map.DefaultValues = {
  broadcasting: false,
  error: false,
  available: false,
  viewport: airports.LAX,
  locations: [],
  removedLocations: [],
  mapIsOpen: false,
  showBoundsOptions: {
    maxZoom: airports.LAX.zoom
  },
  movePoint() {}
}

Map.points = {}
Map.removedPoints = {}

Map.Context = createContext(Map.DefaultValues)

Map.Decorator = function withMapContext(Component) {
  return (props) => (
    <Map.Context.Consumer>
      {mapProps => <Component {...props} mapContext={mapProps} />}
    </Map.Context.Consumer>
  )
}

const wrapperStyle = {
  width: '100%',
  height: '75vh'
}

export default class ReduxMapProvider extends Component {
  constructor(props) {
    super(props)
    this._updateLocations = throttle(this._updateLocations, 500, true)
    this.state = {
      ...Map.DefaultValues,
      hideMap: this.hideMap,
      movePoint: this.movePoint,
      removePoint: this.removePoint,
      showMap: this.showMap,
      startBroadcast: this.startBroadcast,
      stopBroadcast: this.stopBroadcast,
      toggleBroadcast: this.toggleBroadcast,
      toggleMap: this.toggleMap,
    }
  }

  locations = {}

  get _viewportAsPoint() {
    try {
      return [ this.state.viewport.longitude, this.state.viewport.latitude ]
    } catch(err) {
      return []
    }
  }

  _addWatch = () =>
    this.watcher =  this.watcher
                    || navigator.geolocation.watchPosition(this._onLocation, this._onError, { enableHighAccuracy: true })

  _broadcastDidStop = () => this.channel.perform('stopped')

  _closeChannel = () => {
    this.channel && CoachLocationChannel.closeChannel('LAX', this._onCoachLocationReceived)
  }

  _onCoachLocationReceived = ({ airport, eventType, data }) => {
    switch (eventType) {
      case 'connected':
        return this.channel.perform('joined')
      case 'received':
        try {
          const { id, latitude, longitude, action } = data

          switch (action) {
            case 'joined':
              return this.state.broadcasting && this._onLocation(this._currentLocation)
            case 'stopped':
              return this.removePoint(id)
            case 'located':
              return this.movePoint({
                id,
                coordinates: [ longitude, latitude ]
              })
            default:
              if(process.env.NODE_ENV === 'development') console.info(airport, data)
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

  _onError = (err) => {
    console.error(err)
    this.stopBroadcast()
    this.setState({ error: err.message || err.toString() })
  }

  _getChannel = () => {
    if(AuthStatus.dusId) {
      this.channel = this.channel || CoachLocationChannel.openChannel('LAX', this._onCoachLocationReceived)
      this.setState({ available: true })
    } else {
      if(this.state.available) this.setState({ available: false })
    }
  }

  _toRadians = v => +v * Math.PI / 180

  _getDistance = (point) => {
    const R = 6371e3, // metres around the earth
          [ lng1, lat1 ] = this._viewportAsPoint,
          [ lng2, lat2 ] = point;

    const φ1 = this._toRadians(lat1),
          φ2 = this._toRadians(lat2),
          Δφ = this._toRadians(lat2-lat1),
          Δλ = this._toRadians(lng2-lng1),
          a = Math.sin(Δφ/2) *
              Math.sin(Δφ/2) +
              Math.cos(φ1) *
              Math.cos(φ2) *
              Math.sin(Δλ/2) *
              Math.sin(Δλ/2),
          c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

    return R * c;
  }

  _onLocation = (data) => {
    this._currentLocation = data
    if(this.channel) this.channel.perform('located', { latitude: data.coords.latitude, longitude: data.coords.longitude })
  }

  _onLocationViewportChange = ({ zoom: _, ...viewport }) => {
    this._onViewportChange({ ...viewport, zoom: this.state.viewport.zoom || 14 })
  }

  _onViewportChange = viewport => {
    viewport.pitch = 0
    this.setState({ viewport }, this._updateLocations)
  }

  _pointDidChange(point) {
    // if(!point.id || AuthStatus.dusId === point.id) return false

    let saved = Map.points[point.id] || []

    return  !saved.length
            || (saved[0] !== point.coordinates[0])
            || (saved[1] !== point.coordinates[1])
  }

  _selectAirport = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    const el = ev.currentTarget,
        airport = el.value
    if(airport) {
      this.setState({ airport, viewport: airports[airport] })
      setTimeout(() => {
        if(el.value === airport) el.value = ''
      }, 1500)
    }
  }

  _mapPoints = points => {
    const locations = [];
    for (let id in points) {
      const point = points[id]
      if(this._getDistance(point) < 5000) {
        locations.push(point)
      }
    }
    return locations
  }

  _updateLocations = () => {
    const locations = this._mapPoints(Map.points),
          removedLocations = this._mapPoints(Map.removedPoints);

    this.setState({ locations, removedLocations })
  }

  componentDidMount() {
    AuthStatus.subscribe(this._getChannel)
    this._getChannel()
  }

  componentWillUnmount() {
    AuthStatus.unsubscribe(this._getChannel)
    this._closeChannel()
  }

  hideMap   = () => this.setState({ mapIsOpen: false })

  mapRef = (...args) => console.log(args)

  movePoint = point => {
    delete Map.removedPoints[point.id]

    if(this._pointDidChange(point)) {
      Map.points[point.id] = point.coordinates
      this._updateLocations()
    }
  }

  removePoint = id => {
    const point = Map.points[id]

    if(point) {
      delete Map.points[id]

      Map.removedPoints[id] = point
      this._updateLocations()
    }
  }

  showMap = () => this.setState({ mapIsOpen: true })

  startBroadcast = () => {
    this.setState({
      broadcasting: true
    }, this._addWatch)
  }

  stopBroadcast = () => {
    navigator.geolocation.clearWatch(this.watcher)
    this.watcher = null
    this._broadcastDidStop()
    this.setState({ broadcasting: false })
  }

  toggleBroadcast = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.state.broadcasting ? this.stopBroadcast() : this.startBroadcast()
  }

  toggleMap = () => this.setState({ mapIsOpen: !this.state.mapIsOpen })

  render() {
    return (
      <Map.Context.Provider
        value={this.state}
      >
        {
          this.state.error && (
            <div className="row ">
              <div className="col-12">
                <div className="mt-3 alert alert-danger" role="alert">
                  { this.state.error }
                </div>
              </div>
            </div>
          )
        }
        {
          this.state.available && (
            <div className="row">
              <div className="col form-group">
                <button className="btn btn-block btn-info mb-3" onClick={this.toggleBroadcast}>
                  {
                    this.state.broadcasting
                    ? 'Stop Broadcasting'
                    : 'Broadcast your Location'
                  }
                </button>
              </div>
              <div className="col form-group">
                <button
                  className="btn btn-block btn-info form-group"
                  onClick={this.toggleMap}
                >
                  Toggle Live Location Map
                </button>
              </div>
              {
                this.state.mapIsOpen && (
                  <div className="col-md-4 corm-control">
                    <select
                      name="airport_select"
                      onChange={this._selectAirport}
                      className="form-control"
                    >
                      <option value="">
                        Select Airport
                      </option>
                      <option value="LAX">
                        Los Angeles, CA
                      </option>
                      <option value="YVR">
                        Vancouver, CAN
                      </option>
                      <option value="YYZ">
                        Toronto, CAN
                      </option>
                    </select>
                  </div>
                )
              }
              <div className="col-12">
                {
                  this.state.mapIsOpen && (
                    <div style={wrapperStyle}>
                      <MapGL
                        mapRef={this.mapRef}
                        {...this.state.viewport}
                        width="100%"
                        height="100%"
                        mapStyle="mapbox://styles/mapbox/dark-v9"
                        onViewportChange={this._onViewportChange}
                      >
                        <ScatterplotOverlay
                          locations={this.state.removedLocations}
                          dotFill="#AAA"
                          dotRadius={10}
                          globalOpacity={0.8}
                          compositeOperation="lighter"
                          renderWhileDragging={true}
                        />
                        <ScatterplotOverlay
                          locations={this.state.locations}
                          dotRadius={10}
                          globalOpacity={0.8}
                          compositeOperation="lighter"
                          renderWhileDragging={true}
                        />
                        <div className="float-right p-3">
                          <NavigationControl
                            showZoom={true}
                            showCompass={true}
                          />
                        </div>
                        <GeolocateControl
                          style={geolocateStyle}
                          positionOptions={{enableHighAccuracy: true}}
                          trackUserLocation={true}
                          showUserLocation={true}
                          fitBoundsOptions={this.state.showBoundsOptions}
                          onViewportChange={this._onLocationViewportChange}
                        />
                      </MapGL>
                    </div>
                  )
                }
              </div>
            </div>
          )
        }
        {this.props.children}
      </Map.Context.Provider>
    )
  }
}
