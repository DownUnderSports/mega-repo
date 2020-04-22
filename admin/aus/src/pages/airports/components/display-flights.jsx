import React, { Component, Fragment } from 'react';
import { SelectField } from 'react-component-templates/form-components';

const formatDate = (date) => `${date.getFullYear()}-0${date.getMonth() + 1}-0${date.getDate()}`.replace(/-0\d{2}/g, (v) => `-${v.slice(2)}`)
const dateFromYYMMDD = (str) => new Date(...str.split('-').map((v, i) => +v - (i === 1 ? 1 : 0)))

export default class DisplayFlights extends Component {
  get airports() {
    try {
      return this.state.airports || []
    } catch(_) {
      return []
    }
  }

  get data() {
    return this.state.data || {}
  }

  get selectedDate() {
    return this.state.selectedDate || ''
  }

  get options() {
    return this.state.options || []
  }

  get totalTravelers() {
    return this.state.dates[this.selectedDate] || 0
  }

  constructor(props) {
    super(props)

    try {
      this.state = { ...this.extractDataFromProps(props), selectedDate: formatDate(new Date()), selectedDatePretty: new Date().toDateString(), showing: {} }
    } catch(_) {}
  }

  componentDidMount() {
    this._isMounted = true
  }

  componentWillUnmount() {
    this._isMounted = false
  }

  componentDidUpdate(props, { selectedDate }) {
    if(props !== this.props) {
      if(!this.state.reparsing) this.setState({ reparsing: true })
      clearTimeout( this._reParse )
      this._reParse = setTimeout(() => {
        if(this._isMounted) this.setState({...this.extractDataFromProps(this.props), reparsing: false})
      }, 1000)
    }
  }

  extractDataFromProps(props) {
    try {
      const { inboundDomesticFlightsModel: { data: records = [] } } = props

      const data  = {},
            dates = {}

      for(let i = 0; i < records.length; i++) {
        const { date, code, flights = [] } = records[i] || {}


        if(date) {
          dates[date] = dates[date] || 0
          data[code] = data[code] || {}
          data[code][date] = data[code][date] || {
            records: [],
            coaches: [],
            total: 0
          }

          let codeDate = data[code][date]
          for(let f = 0; f < flights.length; f++) {
            let { arrivingAt, departingAt, coaches = [], flightNumber, ...flight } = flights[f]

            arrivingAt = arrivingAt === 'N/A' ? 'N/A' : new Date(arrivingAt.replace(/-\d{2}:\d{2}$/, '')).toLocaleTimeString()
            departingAt = departingAt === 'N/A' ? 'N/A' : new Date(departingAt.replace(/-\d{2}:\d{2}$/, '')).toLocaleTimeString()

            codeDate.records.push({...flight, arrivingAt, departingAt, flightNumber, key: `${code}.${arrivingAt}.${departingAt}.${flightNumber}` })

            codeDate.total = codeDate.total + +flight.total
            dates[date] = dates[date] + +flight.total

            for(let c = 0; c < coaches.length; c++) {
              codeDate.coaches.push(coaches[c])
            }
          }
        }
      }

      const options = Object.keys(dates).sort().map((date) => {
        let parsed = dateFromYYMMDD(date)

        return {
          value: date,
          locale: parsed.toLocaleDateString(),
          string: parsed.toDateString(),
          label: `${parsed.toLocaleDateString()} (${parsed.toDateString()})`
        }
      })

      const airports = Object.keys(data).sort()

      return { airports, data, dates, options, }
    } catch(err) {
      console.log(err)

      return {
        airports: [],
        data: {},
        dates: {},
        options: [],
      }
    }
  }

  selectedCoaches = (code) => {
    try {
      if(!this.state.selectedDate) return ''
      return (this.data[code][this.state.selectedDate].coaches || []).sort().join(', ')
    } catch(_) {
      return ''
    }
  }

  selectedInfo = (code) => {
    try {
      if(!this.state.selectedDate) return []
      return this.data[code][this.state.selectedDate].records || []
    } catch(_) {
      return []
    }
  }

  selectedTotal = (code) => {
    try {
      if(!this.state.selectedDate) return []
      return this.data[code][this.state.selectedDate].total || 0
    } catch(_) {
      return 0
    }
  }

  onDateSelect = (_, { value }) => {
    value = String(value || '') || formatDate(new Date())
    this.setState({ selectedDate: value, selectedDatePretty: dateFromYYMMDD(value).toDateString(), showingRecord: '' })
  }

  toggleCode = (code) => {
    const showing = {...this.state.showing}
    showing[code] = !showing[code]
    this.setState({ showing })
  }

  _onFlightClick = (ev) => {
    const el = ev.currentTarget,
          { key: showingRecord = '' } = el.dataset || {}

    if(this.state.showingRecord === showingRecord) {
      this.setState({ showingRecord: '' })
    } else {
      this.setState({ showingRecord })
    }
  }

  render() {
    const { loadingRecords } = (this.props.inboundDomesticFlightsModel || {})

    return (
      <>
        {
          loadingRecords && <h4 className="my-3 d-print-none">
            { loadingRecords }
          </h4>
        }
        <div className="row form-group">
          <div className="col-12">
            <label className="d-print-none" htmlFor="select_domestic_air_date">
              Select Travel Date
            </label>
            <SelectField
              id="select_domestic_air_date"
              viewProps={{
                className:'form-control d-print-none',
              }}
              options={this.options}
              filterOptions={{
                indexes: ['value', 'locale', 'string'],
              }}
              value={this.selectedDate}
              onChange={this.onDateSelect}
              skipExtras
            />
          </div>
        </div>
        <div className="row">
          <div className="col">
            <h3 className="mb-3">
              <strong>{ this.state.selectedDatePretty }:</strong> { this.totalTravelers } Total Travelers
            </h3>
            <div className="table-nowrap">
              <table className="table">
                <tbody>
                  {
                    !this.state.reparsing && this.airports.map((code) => {
                      const { total, coaches = [], records = [] } = this.data[code][this.selectedDate] || {}
                      return !!total && (
                        <Fragment key={`${this.selectedDate}.${code}.${total}`}>
                          <tr onClick={() => this.toggleCode(code)} className="bg-light-blue clickable">
                            <th style={{fontSize: '1.75em'}} colSpan="3">
                              { code } ({total})
                            </th>
                            <th key={`${this.selectedDate}.${code}.${total}.innerTwo`} colSpan="8" className="text-right">
                              {
                                !!coaches.length && <span>
                                  AIRPORT STAFF: { coaches.map(
                                    (c, i) =>
                                      <Fragment key={`${this.selectedDate}.${code}.${c}`}>{c}{(i < (coaches.length - 1)) && <br/>}</Fragment>
                                  ) }
                                </span>
                              }
                            </th>
                          </tr>
                          <tr
                            key={`${this.selectedDate}.${code}.${total}.codeToggle`}
                            onClick={() => this.toggleCode(code)}
                            className={`clickable d-print-none ${this.state.showing[code] ? 'd-screen-none' : ''}`}
                          >
                            <th colSpan="11" className="pb-5 text-center">
                              CLICK HEADER TO TOGGLE
                            </th>
                          </tr>
                          <tr
                            key={`${this.selectedDate}.${code}.${total}.header`}
                            className={this.state.showing[code] ? '' : 'd-screen-none'}
                          >
                            <th colSpan="2">
                              Arriving At
                            </th>
                            <th colSpan="2">
                              Flight Number
                            </th>
                            <th colSpan="2">
                              Passengers
                            </th>
                            <th colSpan="2">
                              Departing At
                            </th>
                            <th colSpan="2">
                              Departing From
                            </th>
                            <th></th>
                          </tr>
                          {
                            records.map(({ arrivingAt, departingAt, departingFrom, flightNumber, total, inbound = [], key }, i) => (
                              <Fragment key={`${this.selectedDate}.${code}.${flightNumber}.${arrivingAt}`}>
                                <tr
                                  key={`${this.selectedDate}.MAIN.${key}`}
                                  className={this.state.showing[code] ? '' : 'd-screen-none'}
                                >
                                  <td colSpan="2">
                                    { arrivingAt }
                                  </td>
                                  <td colSpan="2">
                                    { flightNumber }
                                  </td>
                                  <td colSpan="2">
                                    { total }
                                  </td>
                                  <td colSpan="2">
                                    { departingAt }
                                  </td>
                                  <td colSpan="2">
                                    { departingFrom }
                                  </td>
                                  <td
                                    className="clickable"
                                    onClick={this._onFlightClick}
                                    data-key={key}
                                  >
                                    <i className="material-icons d-print-none">
                                      {
                                        !!inbound.length && (
                                          (key === this.state.showingRecord)
                                            ? 'arrow_drop_up'
                                            : 'arrow_drop_down'
                                        )
                                      }
                                    </i>
                                  </td>
                                </tr>
                                {
                                  (key === this.state.showingRecord)
                                  && (
                                    <tr
                                      key={`${this.selectedDate}.INBOUND.${key}`}
                                      className={this.state.showing[code] ? 'd-print-none' : 'd-none'}
                                    >
                                      <th>
                                        <i className="material-icons d-print-none clickable">
                                          chevron_right
                                        </i>
                                      </th>
                                      <td colSpan="10" className="p-0">
                                        {
                                          inbound.length ? (
                                            <table className="table font-italic">
                                              <thead>
                                                {
                                                  /Own Domestic|No Additional Airfare/.test(flightNumber)
                                                    ? (
                                                      <tr>
                                                        <th className="border-top-0">
                                                          DUS ID
                                                        </th>
                                                        <th className="border-top-0">
                                                          Name
                                                        </th>
                                                        <th className="border-top-0">
                                                          Team
                                                        </th>
                                                        <th className="border-top-0">
                                                          Category
                                                        </th>
                                                        <th className="border-top-0">
                                                        </th>
                                                        <th className="border-top-0">
                                                        </th>
                                                      </tr>
                                                    )
                                                    : (
                                                      <tr>
                                                        <th className="border-top-0">
                                                          Flight Number
                                                        </th>
                                                        <th className="border-top-0">
                                                          From
                                                        </th>
                                                        <th className="border-top-0">
                                                          To
                                                        </th>
                                                        <th className="border-top-0">
                                                          Departing
                                                        </th>
                                                        <th className="border-top-0">
                                                          Arriving
                                                        </th>
                                                        <th className="border-top-0">
                                                          Count
                                                        </th>
                                                      </tr>
                                                    )
                                                }
                                              </thead>
                                              <tbody>
                                                {
                                                  inbound.map((r, i) => (
                                                    <tr key={i}>
                                                      <td>
                                                        { r.flightNumber }
                                                      </td>
                                                      <td>
                                                        { r.departingFrom }
                                                      </td>
                                                      <td>
                                                        { r.arrivingTo }
                                                      </td>
                                                      <td>
                                                        { r.departingAt }
                                                      </td>
                                                      <td>
                                                        { r.arrivingAt }
                                                      </td>
                                                      <td>
                                                        { r.total }
                                                      </td>
                                                    </tr>
                                                  ))
                                                }
                                              </tbody>
                                            </table>
                                          ) : (
                                            <span className="d-block text-center p-3 text-muted font-italic">
                                              No Other Flights
                                            </span>
                                          )
                                        }
                                      </td>
                                    </tr>
                                  )
                                }
                              </Fragment>
                            ))
                          }
                        </Fragment>
                      )
                    }).filter((v) => !!v)
                  }
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </>

    )
  }
}
