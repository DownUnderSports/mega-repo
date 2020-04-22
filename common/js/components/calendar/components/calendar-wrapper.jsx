import React, { Component, forwardRef } from 'react'

class CalendarWrapper extends Component {
  render() {
    return (
      <div
        className="calendar-wrapper"
        style={{padding: `${this.props.size || 50}${this.props.sizeUnit || '%'}`}}
        ref={this.props.calendarRef}
      >
        <div className="calendar-holder">
          <div
            className="calendar form-group"
            style={this.props.style || {}}
            tabIndex={(+(this.props.tabIndex || 0) < 0) ? -1 : 0}
            onBlur={this.onBlur}
          >
            {this.props.children}
          </div>
        </div>
      </div>
    );
  }
}

export default forwardRef((props, ref) => <CalendarWrapper calendarRef={ref} {...props} />)
