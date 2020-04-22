import React, { PureComponent } from 'react'
import dateFns from 'date-fns'

export default class CalendarBody extends PureComponent {
  buildRows = () => {
    const {
      endDate,
      startDate,
      dayFormat,
      selectedDate,
      monthStart,
    } = this.props,
    rows = [];

    let day = startDate
    console.log(this.props)
    while (day <= endDate) {
      console.log(this.getDays(day, this.props))
      let {days, day: currentDay} = this.getDays(day, this.props)
      day = currentDay
      rows.push(
        <div className="calendar-row" key={day}>
          {days}
        </div>
      );
    }

    return rows
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
        formattedDate = '';

    for (let i = 0; i < 7; i++) {
      formattedDate = dateFns.format(day, dayFormat);
      const cloneDay = day;
      days.push(
        <div
          className={`calendar-col cell ${
            !dateFns.isSameMonth(day, monthStart)
              ? "disabled"
              : dateFns.isSameDay(day, selectedDate) ? "selected" : ""
          }`}
          key={day}
          onClick={() => onClick(dateFns.parse(cloneDay))}
        >
          <span className="number">{formattedDate}</span>
          <span className="bg">{formattedDate}</span>
        </div>
      );
      day = dateFns.addDays(day, 1);
    }

    return {day, days}
  }

  render() {
    return (
      <div className="calendar-body">
        {
          this.buildRows()
        }
      </div>
    );
  }
}
