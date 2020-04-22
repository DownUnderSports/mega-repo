import React, { Component } from 'react';
import { SelectField }      from 'react-component-templates/form-components';
import SortableTable        from 'components/sortable-table'
import CheckInForm          from 'forms/check-in-form'

const formatDate = (date) => `${date.getFullYear()}-0${date.getMonth()}-0${date.getDate()}`.replace(/-0\d{2}/g, (v) => `-${v.slice(2)}`)
const dateFromYYMMDD = (str) => new Date(...str.split('-').map((v, i) => +v - (i === 1 ? 1 : 0)))

const tableHeaders = [
        "isCheckedInYesNo",
        "date",
        "code",
        "dusId",
        "category",
        "fullName",
        "airportName",
        "localDepartingTime",
        "wristband",
      ], headerAliases = {
        airportName:        'Airport Name',
        dusId:              'DUS ID',
        fullName:           'Full Name',
        isCheckedInYesNo:   'Checked In?',
        localDepartingTime: 'Departing At',
      }

export default class DisplayFlights extends Component {
  get selectedDate() {
    return this.state.selectedDate || ''
  }

  get selectedCode() {
    return this.state.selectedCode || ''
  }

  get dateOptions() {
    return this.state.dateOptions || []
  }

  get airportOptions() {
    return this.state.airportOptions || []
  }

  get count() {
    return (this.state.filtered || []).length
  }

  _cellRenderer = (row, header) =>
    header === 'isCheckedInYesNo'
      ? row.isCheckedIn
        ? <span className="text-success">Yes</span>
        : <span className="text-danger">No</span>
      : row[header]

  constructor(props) {
    super(props)

    try {
      this.state = {
        ...this.extractDataFromProps(props),
        selectedDate: '',
        selectedDatePretty: '',
        selectedCode: '',
        selectedCodePretty: '',
        filtered: []
      }
    } catch(_) {
      this.state = {
        records: [],
        airportOptions: [],
        dateOptions: [],
        selectedDate: '',
        selectedDatePretty: '',
        selectedCode: '',
        selectedCodePretty: '',
        filtered: []
      }
    }
  }

  componentDidMount() {
    const d = formatDate(new Date())
    if(this.state.dateOptions && this.state.dateOptions.includes((v) => v.value === d)) {
      this.setState({
        selectedDate: d,
        selectedDatePretty: new Date().toDateString(),
      })
    } else {
      this.filterRecords()
    }
  }

  componentDidUpdate(props) {
    if(props.outboundInternationalFlightsModel && (props.outboundInternationalFlightsModel.data !== this.props.outboundInternationalFlightsModel.data)) {
      this.setState(this.extractDataFromProps(this.props), this.filterRecords)
    }
  }

  extractDataFromProps(props) {
    try {
      const { outboundInternationalFlightsModel: { data: records = [] } } = props

      const dates = {},
            airports = {}

      for(let i = 0; i < records.length; i++) {
        const { date, code, airportName, isCheckedIn } = records[i] || {}

        records[i].isCheckedInYesNo = isCheckedIn ? 'Yes' : 'No'

        if(code) {
          airports[code] = airports[code] || airportName
        }

        if(date) {
          dates[date] = dates[date] || 0
        }
      }

      const dateOptions = Object.keys(dates).sort().map((date) => {
        let parsed = dateFromYYMMDD(date)

        return {
          value: date,
          locale: parsed.toLocaleDateString(),
          string: parsed.toDateString(),
          label: `${parsed.toLocaleDateString()} (${parsed.toDateString()})`
        }
      })

      const airportOptions = Object.keys(airports).sort().map(
        code => ({
          value: code,
          label: `${code}: ${airports[code]}`
        })
      )

      return { airportOptions, dateOptions, records }
    } catch(err) {
      console.log(err)

      return {
        airportOptions: [],
        dateOptions:    [],
        records:        [],
      }
    }
  }

  onDateSelect = (_, { value, string }) => {
    value = String(value || '')
    const newState = {
      selectedDate: '',
      selectedDatePretty: '',
    }
    if(value) {
      newState.selectedDate = value
      newState.selectedDatePretty = string
    }

    this.setState(newState, this.filterRecords)
  }

  onCodeSelect = (_, { value, label }) => {
    this.setState({ selectedCode: value, selectedCodePretty: label }, this.filterRecords)
  }

  filterRecords = () => {
    if(!this.state.records || !this.state.records.length) return this.setState({ filtered: [] })
    this.setState({
      filtered: this.state.records.filter((v) => {
        if(this.state.selectedCode) {
          if(v.code !== this.state.selectedCode) return false
        }

        if(this.state.selectedDate) {
          if(v.date !== this.state.selectedDate) return false
        }

        return true
      })
    })
  }

  render() {
    const { loadingRecords } = this.props.outboundInternationalFlightsModel || {}

    return (
      <>
        <div className="row">
          <div className="col-12 d-print-none">
            <div className="card">
              <h3 className="card-header">
                Check In Traveler
              </h3>
              <div className="card-body">
                <CheckInForm />
              </div>
            </div>
          </div>
          <div className="col-12">
            <h3 className="mb-3">
              <div className="row d-screen-none">
                <div className="col">
                  {
                    !!(this.selectedCode || this.selectedDate) && (
                      <strong>
                        { this.state.selectedCodePretty }
                        { this.selectedDate && <span> on { this.state.selectedDatePretty }</span> }:
                        &nbsp;
                      </strong>
                    )
                  }
                  { this.count } Travelers
                </div>
                {
                  (!this.selectedDate || !this.selectedCode) && (
                    <div className="col">
                      Select a Date and Airport to Print Full Table
                    </div>
                  )
                }
              </div>
            </h3>
          </div>
          <div className="col-12">
            <SortableTable
              headers={tableHeaders}
              data={this.state.filtered || []}
              headerAliases={headerAliases}
              printable={!!this.selectedDate && !!this.selectedCode}
              renderer={this._cellRenderer}
            >
              <div className="row form-group">
                <div className="col">
                  <label className="d-print-none" htmlFor="select_domestic_air_date">
                    Select Travel Date
                  </label>
                  <SelectField
                    id="select_outbound_intl_air_date"
                    viewProps={{
                      className:'form-control d-print-none',
                    }}
                    options={this.dateOptions}
                    filterOptions={{
                      indexes: ['value', 'locale', 'string'],
                    }}
                    value={this.selectedDate}
                    onChange={this.onDateSelect}
                    skipExtras
                  />
                </div>
                <div className="col">
                  <label className="d-print-none" htmlFor="select_domestic_air_date">
                    Select Airport
                  </label>
                  <SelectField
                    id="select_outbound_intl_air_code"
                    viewProps={{
                      className:'form-control d-print-none',
                    }}
                    options={this.airportOptions}
                    filterOptions={{
                      indexes: ['value', 'label'],
                    }}
                    value={this.selectedCode}
                    onChange={this.onCodeSelect}
                    skipExtras
                  />
                </div>
                {
                  loadingRecords && (
                    <div className="col-12 mt-3">
                      <h4>
                        { loadingRecords }
                      </h4>
                    </div>
                  )
                }

              </div>
            </SortableTable>
          </div>
        </div>
      </>

    )
  }
}
