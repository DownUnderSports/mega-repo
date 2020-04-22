import React, { Component } from 'react'
import PropTypes from 'prop-types';

export default class CheckboxGroup extends Component {
  static propTypes = {
    id: PropTypes.string,
    className: PropTypes.string,
    value: PropTypes.array,
    label: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.node,
    ]),
    options: PropTypes.arrayOf(PropTypes.shape({
      label: PropTypes.string.isRequired,
      value: PropTypes.string.isRequired
    })).isRequired,
    clicked: PropTypes.func,
    onError: PropTypes.func,
    onChange: PropTypes.func,
  };

  get clicked() {
    return this.props.clicked || (() => true)
  }

  handleChange = (event) => {
    const el = event.currentTarget
    const shouldContinue = this.clicked(el, (el.dataset || {}).label, event)

    if(shouldContinue) {
      const arr = [...(this.props.value || [])];

      if (el.checked) {
        arr.push(el.value);
      } else {
        arr.splice(arr.indexOf(el.value), 1);
      }
      this.props.onChange && this.props.onChange({
        ...event,
        currentTarget: {...el, ...this.props, value: arr}
      });
      return arr
    } else {
      event.preventDefault();
      event.stopPropagation();
      this.props.onError(el, (el.dataset || {}).label, event)
      return false
    }


  }

  render() {
    const { value: inputValue = [], name = '', id = name, label: inputLabel = '', className = '', options = [] } = this.props

    return (
      <div className={`btn-group btn-group-toggle ${className}`} data-toggle="buttons">
        {inputLabel}
        {
          options.map(({label, value}, i) =>{
            const checked = inputValue.includes(value);
            return  (
              <label
                className={`btn ${checked ? 'btn-primary active' : 'btn-light'}`}
                key={`checkbox.${i}`}
                id={`${id}_${i}_label`}
              >
                <input
                  id={`${id}_${i}`}
                  type="checkbox"
                  name={`${name}[${i}]`}
                  checked={checked}
                  value={value}
                  onChange={this.handleChange}
                  data-label={label}
                />
                <span>{label}</span>
              </label>
            )
          })
        }
      </div>
    )
  }
}
