import React, { Component, forwardRef } from 'react'
import dateFns from 'date-fns'

class CalendarLabels extends Component {
  render() {
    return (
      <div ref={this.props.calendarRef} className="calendar-labels calendar-row">
        {
          [...Array(7)].map((_, i) => (
            <div data-purpose='calendar-label' className="calendar-col col-center" key={i}>
              <div className="col-overflow">
                {dateFns.format(dateFns.addDays(this.props.startDate, i), this.props.labelFormat)}
              </div>
            </div>
          ))
        }
      </div>
    );
  }
}

export default forwardRef((props, ref) => <CalendarLabels calendarRef={ref} {...props} />)
