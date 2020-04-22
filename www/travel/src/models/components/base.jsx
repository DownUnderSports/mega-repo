import React, { Component } from 'react'
import BaseModel from 'models/base'
import throttle from 'helpers/throttle'

export default class BaseModelComponent extends Component {

  constructor(props) {
    super(props)

    this.liveData = []
    this.liveKeys = {}

    this.state = {
      data: [],
      keys: {},
      offline: true,
      lastUpdated: '',
      totals: {},
    }
  }

  async componentDidMount() {
    this._isMounted = true
    this.model.register(this.dataCallback)
    this.model.registerStream(this.streamCallback)
    await this.loadContent()
  }

  componentWillUnmount() {
    this._isMounted = false
    this.model.unregister(this.dataCallback)
    this.model.unregisterStream(this.streamCallback)
  }

  get model() {
    return this._model || BaseModel
  }

  set model(model) {
    this._model = model
  }

  get keyPath() {
    return this._keyPath || ['id']
  }

  set keyPath(array) {
    this._keyPath = array
  }

  displayName = () => this.model.storeName.replace(/[a-z][A-Z]/g, (v) => v.split('').join(' ')).titleize().replace(/s$/, '')
  propName = () => `${this.model.storeName}Model`
  mapToKeyPath = (record) => this.keyPath.map(k => String((record || {})[k])).join('.')

  loadContent = async () => await this.model.loadContent()

  dataCallback = (data, lastUpdated, offline) => {
    if(!this._isMounted) return false
    this.liveData = [...data || []]
    this.liveKeys = data.reduce((o, r) => (o[this.mapToKeyPath(r)] = 1) && o, {})

    this.setState({
      data,
      lastUpdated,
      offline,
      keys: {...this.liveKeys}
    })
  }

  streamUpdater = throttle(() => {
    if(!this._isMounted) return false
    this.setState({
      data: [...this.liveData],
      keys: this.liveData.reduce((o, r) => (o[this.mapToKeyPath(r)] = 1) && o, {})
    })
  })


  streamCallback = (record, key) => {
    if(key === "totals") return this.setState({ totals: record })
    if(this.props.noStream || key !== "records") return false
    const kp = this.mapToKeyPath(record)
    if(!this.liveKeys[kp]) {
      this.liveKeys[kp] = 1
      this.liveData.push(record)
      try {
        window.requestAnimationFrame(this.streamUpdater)
      } catch(_) {}
    }
  }


  render() {
    const { children, noStream: _, ...props } = this.props

    return (
      <>
        {
          children
          ? React.cloneElement(children, { ...props, [this.propName()]: this.state})
          : (
            <>
              <div className="row form-group">
                <div className="col">
                  { this.displayName() } Records Loaded: { (this.state.data || []).length } of { this.state.totals.total || 0 }
                </div>
              </div>
              {
                this.displayTable()
              }
            </>
          )
        }
      </>
    )
  }
}
