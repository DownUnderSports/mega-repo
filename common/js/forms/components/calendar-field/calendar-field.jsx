import React, { Component } from 'react';
import dateFns from 'date-fns'
import { Objected } from 'react-component-templates/helpers'
import { TextField } from 'react-component-templates/form-components'
import Calendar from 'common/js/components/calendar'
import './calendar-field.css'

const fullDate = /\d{4}-\d{2}-\d{2}|[Nn]/,
      metaKeys = [ 'name', 'allowBlank', 'noText', 'multiText', 'size', 'calendarStyle', 'calendarProps', 'closeOnSelect', 'tabIndex', 'measurable', 'minimum', 'maximum', 'subLabels' ]

export default class CalendarField extends Component {
  constructor(props){
    super(props)
    if(!this.props.value && this.props.allowBlank) {
      const d = dateFns.parse(new Date())
      this.state = {
        isOpen: false,
        value: '',
        date: d,
        year: '',
        month: '',
        day: '',
        hour: '',
        minute: '',
        zone: -(d.getTimezoneOffset() / 60),
      }
    } else {
      const d = dateFns.parse(`${props.value}`.replace(/[^0-9-]/g, '') || new Date())
      this.state = {
        isOpen: false,
        value: props.value || '',
        date: d,
        year: dateFns.format(d, 'YYYY'),
        month: dateFns.format(d, 'MM'),
        day: dateFns.format(d, 'DD'),
        hour: dateFns.format(d, 'HH'),
        minute: dateFns.format(d, 'mm'),
        zone: -(d.getTimezoneOffset() / 60),
      }
    }
  }

  componentDidMount() {
    document.addEventListener('keydown', this.checkEscape)
  }

  componentWillUnmount() {
    document.removeEventListener('keydown', this.checkEscape)
    this.removeScrollListeners()
  }

  componentDidUpdate({ value }, {value: stateValue, isOpen}){
    if(isOpen !== this.state.isOpen) {
      if(this.state.isOpen) {
        this.addScrollListeners()
      } else {
        this.removeScrollListeners()
      }
    }
    if((stateValue !== this.state.value) || (value !== this.props.value)) {
      const valToUse = ((stateValue !== this.state.value) ? this.state.value : this.props.value) || ''
      const d = dateFns.parse(`${valToUse}`.replace(/[^0-9-]/g, '') || new Date())
      this.setState({
        value: valToUse,
        date: d,
        year: dateFns.format(d, 'YYYY'),
        month: dateFns.format(d, 'MM'),
        day: dateFns.format(d, 'DD'),
        hour: dateFns.format(d, 'HH'),
        minute: dateFns.format(d, 'mm'),
        zone: -(d.getTimezoneOffset() / 60),
      })
    }
  }

  addScrollListeners = () => {
    try {
      this.removeScrollListeners()
      document.body.classList.add("date-modal-open")
    } catch(_) {
      this.removeScrollListeners()
    }
  }

  removeScrollListeners= () => {
    document.body.classList.remove("date-modal-open")
    // this.removeScrollListener(document)
    // this.removeScrollListener(this.refs.wrapper)
  }

  setScrollListener = (el, method) => {
    [ 'scroll', 'touchmove' ].map((v) => {
      try {
        el[method](v, this.scrollFix, false)
      } catch(_) {}
      return v
    })
  }

  removeScrollListener = (el) => {
    this.setScrollListener(el, 'removeEventListener')
  }

  addScrollListener = (el) => {
    this.setScrollListener(el, 'addEventListener')
  }

  scrollFix = (ev) => {
    console.log("scroll", ev.currentTarget)
    if(this.state.isOpen && !this.refs.wrapper.contains(ev.currentTarget)) {
      console.log("prevented")
      ev.preventDefault()
      ev.stopPropagation()
      return false
    }
  }

  checkEscape = (ev) => {
    if(!this.state.isOpen) return false
    ev = ev || window.event;
    let isEscape = false;
    if("key" in ev) {
      isEscape = (ev.key === "Escape" || ev.key === "Esc");
    } else {
      isEscape = (ev.keyCode === 27);
    }
    if(isEscape) this.refs.background.focus()
  }

  multiTextChange = () => {
    const newDt = new Date()
    const val = `${
      String(this.state.year || dateFns.format(newDt, 'YYYY'))
    }-${
      String(this.state.month || dateFns.format(newDt, 'MM'))
    }-${
      String(this.state.day || dateFns.format(newDt, 'DD'))
    }`

    console.log(val, dateFns.format(this.state.date, 'YYYY-MM-DD'))
    if(fullDate.test(val) && (val !== dateFns.format(this.state.date, 'YYYY-MM-DD'))) {
      const d = dateFns.parse(`${val}`.replace(/[^0-9-]/g, '') || new Date())
      const value = `${
        String(this.state.year || '').rjust(4, '0')
      }-${
        String(this.state.month || '').rjust(2, '0')
      }-${
        String(this.state.day || '').rjust(2, '0')
      }` === val ? val : this.state.value

      if(value === val) return this.setValue(value)

      this.setState({
        value,
        date: d,
        year: this.state.year || '',
        month: this.state.month || '',
        day: this.state.day || '',
        hour: this.state.hour || '',
        minute: this.state.minute || '',
        zone: -(d.getTimezoneOffset() / 60),
      })
    }
  }

  handleChange = (d) => {
    this.setState({
      isOpen: !this.props.closeOnSelect
    }, () => this.setValue(`${this.getDirection(this.state.value)}${dateFns.format(d, 'YYYY-MM-DD')}`))
  }

  onTextChange = (ev) => {
    this.setValue(ev.currentTarget.value || '')
  }

  onYearChange = (ev) => {
    let v = ev.currentTarget.value || ''

    // if(/^\d{4}$/.test(String(v))) this.setValue(`${v}-${this.state.month || '01'}-${this.state.day || '01'}`)
    // else
    this.setState({ year: v }, () => /^\d{4}$/.test(String(this.state.year)) && this.multiTextChange())
  }

  onMonthChange = (ev) => {
    let v = ev.currentTarget.value || ''

    // if(/^\d{2}$/.test(String(v))) this.setValue(`${this.state.year || '2000'}-${v}-${this.state.day || '01'}`)
    // else
    this.setState({ month: v }, () => /^\d{2}$/.test(String(this.state.month)) && this.multiTextChange())
  }

  onDayChange = (ev) => {
    let v = ev.currentTarget.value || ''

    // if(/^\d{2}$/.test(String(v))) this.setValue(`${this.state.year || '2000'}-${this.state.month || '01'}-${v}`)
    // else
    this.setState({ day: v }, () => /^\d{2}$/.test(String(this.state.day)) && this.multiTextChange())
  }

  onYearBlur = (ev) => {
    let v = ev.currentTarget.value || ''

    if(/^\d{2}$/.test(String(v))) this.setState({ year: `${/^[01]/.test(v) ? '20' : '19'}${v}` }, this.multiTextChange)
    else if(!/^\d{4}$/.test(String(v))) {
      this.setState({year: '', value: ''})
    } else {
      this.multiTextChange()
    }
  }

  onMonthBlur = (ev) => {
    let v = ev.currentTarget.value || ''

    if(/^\d$/.test(String(v))) this.setState({ month: String(v).rjust(2, 0) }, this.multiTextChange)
    else if (!/^\d{2}$/.test(String(v))) {
      this.setState({month: '', value: ''})
    } else {
      this.multiTextChange()
    }
  }

  onDayBlur = (ev) => {
    let v = ev.currentTarget.value || ''

    if(/^\d$/.test(String(v))) this.setState({ day: String(v).rjust(2, 0) }, this.multiTextChange)
    else if (!/^\d{2}$/.test(String(v))) {
      this.setState({day: '', value: ''})
    } else {
      this.multiTextChange()
    }
  }

  equalTo = (e) => this.setMeasure(e, '', true)
  notEqualTo = (e) => this.setMeasure(e, '!', true)
  greaterThan = (e) => this.setMeasure(e, '>', true)
  greaterThanOrEqual = (e) => this.setMeasure(e, '>=', true)
  lessThan = (e) => this.setMeasure(e, '<', true)
  lessThanOrEqual = (e) => this.setMeasure(e, '<=', true)
  isNull = (e) => this.setMeasure(e, 'NULL')
  isNotNull = (e) => this.setMeasure(e, '!NULL')

  getDirection = (value) => (value || '').replace(/[^><=!]/gi, '') || ''

  setMeasure(ev, direction, clearNull = false) {
    ev.stopPropagation()
    ev.preventDefault()
    this.setValue(`${direction}${this.getValue(this.state.value)}`.replace(clearNull ? /[a-z]/ig : /[^a-z!]/ig, ''))
  }

  getValue = (value) => (value || '').replace(/^[^0-9Nn]+/, '')

  formatValue = value => {
    if(!value) return ''
    return /^[Nn]/.test(value) ? value.toUpperCase().replace(/(NULL)+/i, 'NULL') : dateFns.format(dateFns.parse(value), 'YYYY-MM-DD')
  }

  setValue = (value) => {
    const direction = this.props.measurable ? this.getDirection(value) : ''
    const formatted = this.getValue(value)

    if(this.props.onChange && (!formatted || fullDate.test(formatted))) {
      value = `${direction}${formatted && this.formatValue(formatted)}`

      if(this.props.value === value) this.setState({ value })
      else this.props.onChange(false, { value })

    } else {
      this.setState({ value })
    }
  }

  onBlur = (ev) => {
    if(!fullDate.test(this.state.value || '')){
      this.onChange && this.onChange(false, {value: ''})
    }
    setTimeout(() => {
      try {
        if(!this.refs.wrapper.contains(document.activeElement)) {
          this.setState({isOpen: false}, () => {
            // try {
            //   if(document.activeElement && document.activeElement.tagName !== "BODY") {
            //     document.activeElement.scrollIntoView({behavior: "smooth", block: "center", inline: "center"})
            //   }
            // } catch(_) {  }
          })
        }
      } catch(_) {}
    }, 0)
  }

  onFocus = () => {
    this.setState({isOpen: !this.props.noModal}, () => {

    })
  }

  render() {
    const { name = '', id = name, multiText = false, noText = false, noForm = false, subLabels = !!multiText } = this.props,
          tabIndex = (+(this.props.tabIndex || 0) < 0) ? -1 : 0

    return (
      <div className="row">
        <div className="col">
          <div ref="background" tabIndex="-1" className={this.state.isOpen ? 'fixed-calendar-wrapper' : ''}>
            <div className="fixed-calendar-close-botton clickable">X</div>
            <div
              ref="wrapper"
              className={this.state.isOpen ? 'fixed-calendar-modal' : ''}
              tabIndex={(multiText || !noText) ? -1 : tabIndex}
              onBlur={this.onBlur}
              onFocus={this.onFocus}
            >
              {
                multiText ? (
                  <div className={`row ${this.state.isOpen ? 'form-group size-fix' : ''}`}>
                    <div className="col-12">
                      <label className="form-label d-block">
                        { this.props.label }
                      </label>
                    </div>
                    <div className="col-md">
                      {
                        !subLabels && (
                          <label htmlFor={`${id || name || ''}[year]`}>
                            Year (YYYY)
                          </label>
                        )
                      }
                      <TextField
                        placeholder="(YYYY)"
                        {...Objected.filterKeys(this.props, metaKeys)}
                        name={`${name || ''}[year]`}
                        id={`${id || name || ''}[year]`}
                        skipExtras
                        inputMode="numeric"
                        autoComplete={`false ${new Date()}`}
                        className={this.props.className || ''}
                        value={this.state.year || ''}
                        onChange={this.onYearChange}
                        onBlur={this.onYearBlur}
                        ref='year'
                        pattern={"^\\d{4}$"}
                        tabIndex={tabIndex}
                      />
                      {
                        !!subLabels && (
                          <label className="form-text" htmlFor={`${id || name || ''}[year]`}>
                            <small>
                              Year (YYYY)
                            </small>
                          </label>
                        )
                      }
                    </div>
                    <div className="col-md">
                      {
                        !subLabels && (
                          <label htmlFor={`${id || name || ''}[month]`}>
                            Month (MM)
                          </label>
                        )
                      }
                      <TextField
                        placeholder="(MM)"
                        {...Objected.filterKeys(this.props, metaKeys)}
                        name={`${name || ''}[month]`}
                        id={`${id || name || ''}[month]`}
                        skipExtras
                        inputMode="numeric"
                        autoComplete={`false ${new Date()}`}
                        className={this.props.className || ''}
                        value={this.state.month || ''}
                        onChange={this.onMonthChange}
                        onBlur={this.onMonthBlur}
                        ref='month'
                        pattern={"^\\d{1,2}$"}
                        tabIndex={tabIndex}
                      />
                      {
                        !!subLabels && (
                          <label className="form-text" htmlFor={`${id || name || ''}[month]`}>
                            <small>
                              Month (MM)
                            </small>
                          </label>
                        )
                      }
                    </div>
                    <div className="col-md">
                      {
                        !subLabels && (
                          <label htmlFor={`${id || name || ''}[day]`}>
                            Day (DD)
                          </label>
                        )
                      }
                      <TextField
                        placeholder="(DD)"
                        {...Objected.filterKeys(this.props, metaKeys)}
                        name={`${name || ''}[day]`}
                        id={`${id || name || ''}[day]`}
                        skipExtras
                        inputMode="numeric"
                        autoComplete={`false ${new Date()}`}
                        className={this.props.className || ''}
                        value={this.state.day || ''}
                        onChange={this.onDayChange}
                        onBlur={this.onDayBlur}
                        ref='day'
                        pattern={"^\\d{1,2}$"}
                        tabIndex={tabIndex}
                      />
                      {
                        !!subLabels && (
                          <label className="form-text" htmlFor={`${id || name || ''}[day]`}>
                            <small>
                              Day (DD)
                            </small>
                          </label>
                        )
                      }
                    </div>
                    <TextField
                      placeholder="(YYYY-MM-DD)"
                      {...Objected.filterKeys(this.props, metaKeys)}
                      ref='input'
                      name={name}
                      type='hidden'
                      inputMode="numeric"
                      autoComplete={`false ${new Date()}`}
                      value={this.state.value || ''}
                      onChange={this.onTextChange}
                      skipExtras
                      required
                    />
                  </div>
                ) : (
                  !noText && (
                    (noForm && !this.state.isOpen) ? (
                      <TextField
                        {...Objected.filterKeys(this.props, metaKeys)}
                        ref='input'
                        id={id || name}
                        name={name}
                        className={`${this.state.isOpen ? 'form-group size-fix' : ''} ${this.props.className || ''}`}
                        value={this.state.value ? `${this.state.month}/${this.state.day}/${this.state.year}` : ''}
                        onChange={this.onTextChange}
                        tabIndex={tabIndex}
                      />
                    ) : (
                      <TextField
                        {...Objected.filterKeys(this.props, metaKeys)}
                        ref='input'
                        id={id || name}
                        name={name}
                        className={`${this.state.isOpen ? 'form-group size-fix' : ''} ${this.props.className || ''}`}
                        value={this.state.value || ''}
                        onChange={this.onTextChange}
                        tabIndex={tabIndex}
                      />
                    )
                  )
                )
              }
              {
                (noText || this.state.isOpen) && this.props.measurable && (
                  <div className="row mb-1">
                    <div className="col-auto mb-1 pr-1">
                      <button
                        className='btn btn-info px-0'
                        onClick={this.equalTo}
                        style={{lineHeight: 1, fontSize: '24px'}}
                      >
                        =
                      </button>
                    </div>
                    <div className="col-auto mb-1 px-1">
                      <button
                        className='btn btn-info px-0'
                        onClick={this.notEqualTo}
                        style={{lineHeight: 1, fontSize: '24px'}}
                      >
                        !=
                      </button>
                    </div>
                    <div className="col-auto mb-1 px-1">
                      <button
                        className='btn btn-info px-0'
                        onClick={this.greaterThan}
                        style={{lineHeight: 1, fontSize: '24px'}}
                      >
                        <i
                          className="material-icons"
                        >
                          chevron_right
                        </i>
                      </button>
                    </div>
                    <div className="col-auto mb-1 px-1">
                      <button
                        className='btn btn-info px-0'
                        onClick={this.greaterThanOrEqual}
                        style={{lineHeight: 1, fontSize: '24px'}}
                      >
                        <i
                          className="material-icons"
                        >
                          chevron_right
                        </i>=
                      </button>
                    </div>
                    <div className="col-auto mb-1 px-1">
                      <button
                        className='btn btn-info px-0'
                        onClick={this.lessThan}
                        style={{lineHeight: 1, fontSize: '24px'}}
                      >
                        <i
                          className="material-icons"
                        >
                          chevron_left
                        </i>
                      </button>
                    </div>
                    <div className="col-auto mb-1 px-1">
                      <button
                        className='btn btn-info px-0'
                        onClick={this.lessThanOrEqual}
                        style={{lineHeight: 1, fontSize: '24px'}}
                      >
                        <i
                          className="material-icons"
                        >
                          chevron_left
                        </i>=
                      </button>
                    </div>
                    <div className="col-auto mb-1 px-1">
                      <button
                        className='btn btn-info px-0'
                        onClick={this.isNull}
                        style={{lineHeight: 1, fontSize: '24px'}}
                      >
                        BLANK
                      </button>
                    </div>
                    <div className="col-auto mb-1 pl-1">
                      <button
                        className='btn btn-info px-0'
                        onClick={this.isNotNull}
                        style={{lineHeight: 1, fontSize: '24px'}}
                      >
                        NOT BLANK
                      </button>
                    </div>
                  </div>
                )
              }
              {
                (noText || this.state.isOpen) && (
                  <Calendar
                    ref='calendar'
                    startDate={this.state.date}
                    selectedDate={this.state.value ? this.state.date : null}
                    onClick={this.handleChange}
                    dateFormat="YYYY-MM-DD"
                    tabIndex={tabIndex}
                    size={this.props.size || 75}
                    style={this.props.calendarStyle || {}}
                    {...(this.props.calendarProps || {})}
                    focus
                  />
                )
              }
            </div>
          </div>
        </div>
      </div>


    )
  }
}
