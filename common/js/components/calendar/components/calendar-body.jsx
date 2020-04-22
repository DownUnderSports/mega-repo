import React, { Component, forwardRef } from 'react'
import dateFns from 'date-fns'

class CalendarBody extends Component {
  constructor(props) {
    super(props)
    this.state = {
      cellHeight: '2rem',
      calendarBody: undefined,
      offsetHeight: 32,
    }
  }

  componentDidMount() {
    this.setState({
      reload: true
    })
  }

  componentDidUpdate(prevProps, { rows }) {
    if(prevProps.monthStart !== this.props.monthStart) {
      this.unbind()
      if(this.state.calendarBody) this.setObserver()
    }
    if( rows !== this.state.rows) {
      this.props.onRowCount(this.state.rows)
    }
  }

  buildRows = () => {
    const {
      endDate,
      startDate,
    } = this.props,
    rows = [];

    let day = startDate
    while (day <= endDate) {
      let {days, day: currentDay} = this.getDays(day, this.props)
      day = currentDay
      rows.push(
        <div className="calendar-row" key={day}>
          {days}
        </div>
      );
    }

    if(this.state.rows !== rows.length) setTimeout(() => this.setState({rows: rows.length}))

    return rows
  }

  setCellHeight = (cell) => {
    if(!cell || !cell.offsetHeight || cell.classList.contains('selected')){
      this.unbind()
      this.setObserver()
    } else {
      const offsetHeight = cell.offsetHeight
      if(offsetHeight !== this.state.offsetHeight) {
        this.setState({
          cellHeight: `${offsetHeight}px`,
          offsetHeight,
        })
      }
    }
  }

  setObserver = () => {
    try {
      const cell = this.state.calendarBody.querySelector('.cell:not(.selected)')
      try {
        this.observer = this.observer || new window.ResizeObserver(() => {
          this.setCellHeight(cell)
        })
        this.observer.observe(cell)
      } catch(e) {
        this.observer = void(0)
        this.interval = setInterval(() => {
          this.setCellHeight(cell)
        }, 1000)
      }
    } catch(e) {
      console.error(e)
    }
  }

  setCalendarBody = (el) => {
    if(this.props.calendarRef) this.props.calendarRef(el)

    if(!el) return false
    const cell = el.querySelector('.cell.selected'),
          offsetHeight = cell ? cell.offsetHeight : 0

    this.setState({
      calendarBody: el,
      cellHeight: `${offsetHeight}px`,
      offsetHeight,
    })
  }

  unbind = () => {
    if(this.observer) {
      this.observer.disconnect()
      this.observer = void(0)
    } else {
      clearInterval(this.interval)
      this.interval = void(0)
    }
  }

  componentWillUnmount(){
    this.unbind()
  }

  getDays(day, {
    endDate,
    startDate,
    dayFormat,
    selectedDate,
    monthStart,
    onClick
  }) {
    let days = [],
        formattedDate = '',
        today = new Date();

    for (let i = 0; i < 7; i++) {
      formattedDate = dateFns.format(day, dayFormat);
      const cloneDay = day;
      days.push(
        <div
          className={`calendar-col cell clickable ${
            !dateFns.isSameMonth(day, monthStart) ? "disabled" : ""
          } ${
            dateFns.isSameDay(day, selectedDate)
              ? "selected"
              : dateFns.isSameDay(day, today) ? "today" : ""
          }`}
          key={day}
          onClick={() => onClick(dateFns.parse(cloneDay))}
        >
          <span
            className="bg"
            style={{
              fontSize: this.state.cellHeight,
              // lineHeight: this.state.cellHeight,
              // maxHeight: this.state.cellHeight,
            }}
          >
            {formattedDate}
          </span>
          <span className="number">{formattedDate}</span>
        </div>
      );
      day = dateFns.addDays(day, 1);
    }

    return {day, days}
  }

  render() {
    return (
      <div ref={this.setCalendarBody} className="calendar-body">
        {
          this.buildRows()
        }
      </div>
    );
  }
}

export default forwardRef((props, ref) => <CalendarBody calendarRef={ref} {...props} />)
