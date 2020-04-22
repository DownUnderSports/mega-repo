import React, { Component, PureComponent } from 'react'
import { BooleanField } from 'react-component-templates/form-components';
import Tooltip from 'common/js/components/tooltip'

export class HeaderToggle extends PureComponent {
  toggleHeader = () => this.props.toggleColumn(this.props.header)

  render() {
    const { header = '', checked = false, tooltip =  ''} = this.props

    return (
      <div className="col-12">
        <BooleanField
          className='form-group'
          label={<Tooltip content={tooltip || header}>{header}</Tooltip>}
          toggle={this.toggleHeader}
          checked={checked}
          skipTopLabel
        />
      </div>
    )
  }
}

export default class VisibleColumns extends Component {
  state = { display: false }

  toggle = () => this.setState({ display: !this.state.display })

  get parent() {
    return this.props.parent || {}
  }

  render() {
    const { display } = this.state

    return (
      <div className="border-top mb-2">
        <div className="row">
          <div className="col-12">
            <div className="p-2 border-bottom clickable" onClick={this.toggle}>
              <h5 className='d-inline'>
                Visible Columns:
              </h5>
              <div className="float-right">
                <i
                  className="material-icons"
                >
                  {display ? 'expand_less' : 'expand_more'}
                </i>
              </div>
            </div>
          </div>
          <div className={`col-12 ${display || 'd-none'}`}>
            <div className="p-2 border-bottom">
              <div className="row">
                {
                  this.parent.headers.slice(0).sort().map((h, k) => (
                    <HeaderToggle
                      key={`headerSelect.${h}.${!this.parent.state[`headers-${h}`]}`}
                      header={h}
                      tooltip={this.parent.tooltips[h] || h}
                      toggleColumn={this.parent.toggleColumn}
                      checked={!this.parent.state[`headers-${h}`]}
                    />
                  ))
                }
                <div className='col'>
                  <button
                    className="btn btn-warning float-right"
                    onClick={this.parent.resetColumns}
                  >
                    Reset Columns
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    )
  }
}
