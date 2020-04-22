import React, { Component } from 'react'

export default class Confirmation extends Component {
  render() {
    return (
      <div className="modal fade show d-block" tabIndex="-1" role="dialog">
        <div className="modal-dialog modal-dialog-centered modal-xl" role="document">
          <div className="modal-content">
            <div className="modal-header">
              <h5 className="modal-title">{this.props.title}</h5>
              <button type="button" className="close" onClick={this.props.onCancel} aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div className="modal-body d-flex align-items-center justify-content-center" style={{height: '75vh', overflow: 'scroll'}}>
              <div className="align-self-center" style={{whiteSpace: 'pre-wrap'}}>
                {
                  this.props.children
                }
              </div>
            </div>
            <div className="modal-footer">
              <button
                type="button"
                className="btn btn-success btn-block"
                onClick={this.props.onConfirm}
              >
                {this.props.confirmMessage || 'Confirm'}
              </button>
              <button
                type="button"
                className="btn btn-danger btn-block mt-0"
                onClick={this.props.onCancel}
              >
                {this.props.cancelMessage || 'Cancel'}
              </button>
            </div>
          </div>
        </div>
      </div>
    )
  }
}
