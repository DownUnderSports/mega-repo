import React from 'react'
import { TextField } from 'react-component-templates/form-components';

export function defaultFilterComponent(h, v) {
  return (
    <TextField
      skipExtras
      className='form-control'
      onChange={(ev) => this.onChange(h, ev.target.value)}
      value={v}
      type="text"
      usePhoneFormat={h === 'phone'}
    />
  )
}

export function filterComponent(h) {
  return (
    this.props.filterComponent || this.defaultFilterComponent
  )(
    h,
    this.state[h] || '',
    this.onChange,
    this.defaultFilterComponent
  )
}

export function goToRecord(e, record) {
  if(!this.isDisabled(record)) {
    const id  = String(e.target.dataset.id),
          url = `${this.props.showUrl || this.url()}/${id}`

    if(this.activeKey) localStorage.setItem(this.activeKey, id)

    if(this.props.noRedirect || this.props.onClick) {
      this.props.onClick && this.props.onClick({ id, url })
    } else {
      if(e.ctrlKey) {
        const win = window.open(url, e.shiftKey ? '_blank' : `_show_${this.props.tabKey || 'record'}`);
        win.opener = null
      } else {
        this.props.history.push(url)
      }
    }
  }
}

export function isActive(record) {
  return !!this.activeKey && (String(localStorage.getItem(this.activeKey)) === String(record[this.idKey]))
}

export function isDisabled(record) {
  return this.props.isDisabled && this.props.isDisabled(record)
}

export function printValue(v) {
  if(this.props.printer) return this.props.printer(v)
  return (v == null) ? '' : `${v}`
}

export function rowClassName(record, active){
  return String((this.props.rowClassName || (() => ''))(record, active) || '') + (active ? ' border-active' : '')
}
