import React, { Component } from 'react'
import FilterHistory from './filter-history'

export default class Buttons extends Component {
  get parent() {
    return this.props.parent || {}
  }

  getTotal = () => (
    (this.parent.state.total || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  )

  render() {
    return (
      <div className="col-12">
        <div className="row">
          <div className="col">
            {this.props.renderButtons ? this.props.renderButtons({
              onChange: this.parent.subChange,
              tableState: this.parent.state,
              getParams: this.parent.createParams,
              getRecordCount: this.getTotal,
              reload: this.parent.getRecords,
              location: this.props.location
            }) : this.parent.props.children}
          </div>
          <FilterHistory parent={this.parent} />
          <div className="col-auto text-right form-group btn">
            <strong>
             <i>
               {this.getTotal()} Total Records
             </i>
            </strong>
          </div>
        </div>
      </div>
    )
  }
}
