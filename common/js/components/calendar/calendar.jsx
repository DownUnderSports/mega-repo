import React, { Component } from 'react'
import dateFns from 'date-fns'
import AnimationFrame from 'animation-frame'
import { CalendarHeader, CalendarLabels, CalendarBody, CalendarWrapper } from 'common/js/components/calendar/components'
import './calendar.css'

const headerDateFormat = 'MMMM YYYY',
      labelsDateFormat = "dddd",
      bodyDayFormat = 'D',
      animationListener = new AnimationFrame()

export default class Calendar extends Component {
  static getHeaderText(date, format) {
    return dateFns.format(date, format || headerDateFormat)
  }

  static getWeekStart(date) {
    return dateFns.startOfWeek(date)
  }

  static getWeekEnd(date) {
    return dateFns.endOfWeek(date)
  }

  static getMonthStart(date) {
    return dateFns.startOfMonth(date)
  }

  static getMonthEnd(date) {
    return dateFns.endOfMonth(date)
  }

  static buildStateForMonth(date, props = {}) {
    const startOfMonth = this.getMonthStart(date),
          endOfMonth = this.getMonthEnd(startOfMonth);

    return {
      formattedMonth: this.getHeaderText(date, props.headerFormat),
      startOfMonth,
      endOfMonth,
      startDate: this.getWeekStart(date),
      bodyStartDate: this.getWeekStart(startOfMonth),
      bodyEndDate: this.getWeekEnd(endOfMonth),
    }
  }

  constructor(props) {
    super(props)
    const currentMonth = props.startDate || new Date(),
          selectedDate = props.selectedDate || currentMonth
    this.state = {
      currentMonth,
      selectedDate,
      ...this.constructor.buildStateForMonth(props.startDate || new Date(), props)
    }
  }

  componentDidMount() {
    this._mounted = true
    window.addEventListener('resize', this.callDomRect)
    this.callDomRect()
  }

  componentDidUpdate(prevProps, { size }) {
    if(prevProps.selectedDate !== this.props.selectedDate) {
      const currentMonth = this.props.startDate || new Date(),
            selectedDate = this.props.selectedDate || currentMonth
      this.setState({
        currentMonth,
        selectedDate,
        ...this.constructor.buildStateForMonth(this.props.startDate || new Date(), this.props)
      })
    }
  }

  componentWillUnmount() {
    this._mounted = false
    window.removeEventListener('resize', this.callDomRect)
    this.cancelDomRect()
  }

  changeMonth = (count = 1) => {
    const currentMonth = dateFns.addMonths(this.state.currentMonth, count)

    return this.setState({
      currentMonth,
      ...this.constructor.buildStateForMonth(currentMonth, this.props)
    })
  }

  nextMonth = () => this.changeMonth(1)

  previousMonth = () => this.changeMonth(-1)

  onClick = (selectedDate) => {
    this.setState({selectedDate}, async () => {
      if(!dateFns.isSameMonth(selectedDate, this.state.startOfMonth)){
        const fn = (selectedDate < this.state.startOfMonth ? this.previousMonth : this.nextMonth)
        await fn()
      }
      this.props.onClick && this.props.onClick(selectedDate)
    })
  }

  onBlur = (ev) => {
    console.log(ev)
    this.props.onBlur && this.props.onBlur(ev)
  }

  cancelDomRect = () => {
    if(this._animator) animationListener.cancel(this._animator)
    this._animator = false
  }

  callDomRect = () => {
    if(!this._animator && !this._minimizing) this._animator = animationListener.request(this.setDomRect)
  }

  setDomRect = (time) => {
    this._minimizing = true
    this._animator = false
    this.setState({size: 10, sizeUnit: 'px'}, () => {
      this._animator = animationListener.request(() => {
        this._animator = false
        this._minimizing = false
        this.setState({size: null, sizeUnit: null})
      })
    })
  }

  render() {
    return (
      <CalendarWrapper
        size={this.state.size}
        sizeUnit={this.state.sizeUnit || this.props.sizeUnit}
        className="calendar form-group"
        style={this.props.style || {}}
        tabIndex={(+(this.props.tabIndex || 0) < 0) ? -1 : 0}
        ref="wrapper"
        onBlur={this.onBlur}
      >
        <CalendarHeader
          ref="header"
          month={this.state.formattedMonth}
          onPreviousMonthClick={this.previousMonth}
          onNextMonthClick={this.nextMonth}
        />
        <CalendarLabels
          ref="labels"
          startDate={this.state.startDate}
          labelFormat={this.props.labelFormat || labelsDateFormat}
        />
        <CalendarBody
          ref="body"
          monthStart={this.state.startOfMonth}
          monthEnd={this.state.endOfMonth}
          startDate={this.state.bodyStartDate}
          endDate={this.state.bodyEndDate}
          dayFormat={this.props.dayFormat || bodyDayFormat}
          selectedDate={this.state.selectedDate}
          onClick={this.onClick}
          onRowCount={this.callDomRect}
        />
      </CalendarWrapper>
    );
  }
}
