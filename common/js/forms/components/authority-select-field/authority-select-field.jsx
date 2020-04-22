import React, { Component } from 'react';
import { SelectField, TextField } from 'react-component-templates/form-components';
import AntiLink from 'common/js/components/anti-link'

import authorities from 'common/assets/json/authorities'

const authorityOptions = []

for(let i = 0; i < authorities.length; i++) {
  const { name } = authorities[i]
  authorityOptions.push({
    id: name,
    value: name,
    name,
    label: name || ''
  })
}

export default class AuthoritySelectField extends Component {
  state = { notFound: false }

  onTextChange = ev => this.props.onChange(false, { value: ev.currentTarget.value || '' })

  onTextBlur = ev => this.props.onChange(false, { value: this.formatValue(ev.currentTarget.value) })

  formatValue = str =>
    String(str || '')
    .split(/\s+/)
    .map((v) => /^(of|the)$/.test(v) ? v : v.capitalize() ).join(' ')

  renderTextField = ({ className, name, label, placeholder, value, required, viewProps = {} }) =>
    <TextField
      { ...{ className, name, label, placeholder, value, required, ...viewProps } }
      key={`${name}.input`}
      onChange={this.onTextChange}
      onBlur={this.onTextBlur}
    />

  renderTextFeedback = () =>
    <span className='float-right'>
      <AntiLink
        label='Show Dropdown'
        onClick={()=> this.setState({notFound: false})}
      >

      </AntiLink>
    </span>

  toggle = () => this.setState({notFound: !this.state.notFound})



  render() {


    return (
      <>
        {
          this.state.notFound ? this.renderTextField(this.props) : (
            <SelectField
              {...this.props}
              key={`${this.props.name}.input`}
              options={authorityOptions}
              filterOptions={{
                indexes: ['name'],
              }}
            />
          )
        }
        <small key={`${this.props.name}.feedback`} className="form-text">
          <span className='float-right'>
            <AntiLink
              label='Click Here if Authority Not Listed'
              onClick={this.toggle}
            >
              { this.state.notFound ? "Show Dropdown" : "Click Here if Authority Not Listed" }
            </AntiLink>
          </span>
        </small>
      </>
    )
  }
}
