import React, { Component, forwardRef } from 'react'

class CalendarHeader extends Component {
  render() {
    return (
      <header ref={this.props.calendarRef} className="calendar-header calendar-row flex-middle">
        <div className="calendar-col col-start pl-3">
          <i
            data-function='previous-month'
            className="material-icons clickable"
            onClick={this.props.onPreviousMonthClick}
          >
            chevron_left
          </i>
        </div>
        <h4 data-label='month-name' className="calendar-col col-center">
          {this.props.month}
        </h4>
        <div className="calendar-col col-end pr-3">
          <i
            data-function='next-month'
            className="material-icons clickable"
            onClick={this.props.onNextMonthClick}
          >
            chevron_right
          </i>
        </div>
      </header>
    );
  }
}

export default forwardRef((props, ref) => <CalendarHeader calendarRef={ref} {...props} />)
