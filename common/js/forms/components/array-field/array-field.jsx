import React, { Component, Fragment } from 'react';
import { TextField, TextAreaField } from 'react-component-templates/form-components';

export default class ArrayField extends Component {
  get body() {
    if(!this._body) this._body = window.document.getElementsByTagName('BODY')[0]

    return this._body
  }

  get combined() {
    if(!this.state.value) return ''
    let combo = this.state.value[0] || ''
    for (var i = 1; i < this.state.value.length; i++) {
      combo = `${combo}${this.props.extended ? '\n----------------------------------------\n' : ', '}${this.state.value[i]}`
    }
    return combo
  }

  get wrapperPattern() {
    const pattern = (this.props.pattern || '').replace(/^\^/, '').replace(/\$$/, '')
    return !!pattern ? `^(,?\\s*${pattern})+$` : undefined
  }

  constructor(props) {
    super(props)
    this.state = {
      open: false,
      value: props.value || []
    }
  }

  componentDidUpdate({ value }, {value: stateValue}){
    if(
      !this.state.value.isEqualTo(stateValue) ||
      !Array.equal(value, this.props.value)
    ) {
      const valToUse = (!this.state.value.isEqualTo(stateValue) ? this.state.value : this.props.value) || []

      this.setState({ value: valToUse })
    }
  }

  handleChange = (ev) => {
    const idx = ev.currentTarget.dataset.idx,
          changed = ev.currentTarget.value || ''
    this.setValue(idx, changed)
  }

  setValue(i, v) {
    const { value = [] } = this.state

    value[i] = v

    this.onChange(value)
  }

  onChange = (og) => {
    const value = og || []
    if(this.props.onChange) {
      this.props.onChange(false, { value: [...value], name: this.props.name, key: this.props.formKey })
    } else {
      this.setState({ value })
    }
  }

  openFields = () => this.setState({ open: true })

  addBodyClicker = () => {
    this.eventAdded || (
      (this.eventAdded = true) &&
      this.body.addEventListener('mousedown', this.hideArray)
    )

    const ref = `input${this.state.value.length}`

    try {
      this.refs[ref] && this.refs[ref].refs.input.focus()
    } catch(_) {}

  }

  removeBodyClicker = () => {
    this.body.removeEventListener('mousedown', this.hideArray)
    this.eventAdded = false
  }

  hideArray = (e) => {
    if(!this.refs.wrapper.contains(e.target)) {
      this.removeBodyClicker()
      this.setState({ open: false }, this.clearEmptyValues)
    }
  }

  clearEmptyValues = () => {
    const untouched = this.state.value || [],
          value = []

    for (var i = 0; i < untouched.length; i++) {
      if(untouched[i]) value.push(untouched[i])
    }

    this.onChange(value)
  }

  onBlur = (e) => {
    if(!this.refs.wrapper.contains(e.relatedTarget)) {
      this.setState({ open: false }, this.removeBodyClicker)
    }
  }

  showArray = () => this.setState({ open: true }, this.addBodyClicker)

  addValue = (e) => {
    e.preventDefault()
    e.stopPropagation()
    this.setValue((this.state.value || []).length, '')
  }

  render() {
    const {
      label = '', name, id = name,
      feedback = '', viewProps = {},
      skipExtras = false,
      extended = false, sharedProps = {},
      placeholder, pattern
    } = this.props,
    { open, value = [] } = this.state,
    InputElement = extended ? TextAreaField : TextField,
    DisplayElement = extended ? "textarea" : "input"

    const input = open ? (
      <div
        ref="wrapper"
        onBlur={this.onBlur}
      >
        {
          ([...value, '']).map((v, i) => (
            <InputElement
              key={i}
              className={`form-group form-control`}
              value={v || ''}
              onChange={this.handleChange}
              data-idx={i}
              name={`${name}[${i}]`}
              ref={`input${i}`}
              skipExtras
              pattern={pattern || undefined}
              placeholder={placeholder || undefined}
              {...(sharedProps || {})}
            />
          ))
        }
      </div>
    ) : (
      <DisplayElement
        ref="wrapper"
        className="form-control clickable was-validated"
        name={name}
        onFocus={this.showArray}
        tabIndex="0"
        pattern={this.wrapperPattern}
        placeholder={placeholder || undefined}
        required={!!this.props.required}
        defaultValue={this.combined}
        {...(sharedProps || {})}
        {...(viewProps || {})}
      />
    )

    return skipExtras ? input : (
      <Fragment>
        <label key={`${id}.label`} htmlFor={id}>{label}</label>
        {
          input
        }
        <small key={`${id}.feedback`} className="form-control-focused">
          {feedback}
        </small>
      </Fragment>
    )
  }
}
