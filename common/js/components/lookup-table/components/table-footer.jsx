import React, { PureComponent } from 'react'
import CopyClip from 'common/js/helpers/copy-clip'
import Tooltip from 'common/js/components/tooltip'

export default class TableFooter extends PureComponent {
  get parent() {
    return this.props.parent || {}
  }

  lastPage = () => this.parent.lastPage()

  copyFilter = (e) => {
    if(e.ctrlKey) {
      if(e.shiftKey) {
        CopyClip.unprompted(this.parent.createParams()[0] || '')
      } else {
        CopyClip.unprompted(`${
          window.location.origin
        }${
          window.location.pathname
        }?setFilters=${this.parent.storageKey}&filtersValue=${
          encodeURIComponent(JSON.stringify(this.parent.createParams()[2] || {}))
        }`)
      }
    } else {
      CopyClip.unprompted(JSON.stringify(this.parent.createParams()[2] || {}))
    }
  }

  clearSort = () => {
    if(this.parent.state.sort.length) this.parent.setState({sort: []}, this.parent.state.onChange)
  }

  clearFilters = () => {
    const { changed = false, newState = {} } = this.parent.getCleanState()
    if(changed) this.parent.setState(newState, this.parent.state.onChange)
  }

  firstPage = async () => {
    await (this.parent.state.offset ? this.parent.getRecords(0, 0) : this.parent.setStateAsync({offset: 0, page: 0}))
  }

  nextPage = () => {
    const requestNumber = this.parent.state.requestNumber
    if((this.parent.state.page < (this.parent.state.sheetsPerPage - 1)) && (this.parent.state.records.length > ((this.parent.state.page + 1) * this.parent.state.sheetsPerPage))) {
      this.parent.setState({page: this.parent.state.page + 1}, () => this.parent.saveParams(requestNumber))
    } else if(this.parent.state.records.length === 100) {
      this.parent.getRecords(this.parent.state.offset + 1)
    }
  }

  previousPage = () => {
    const requestNumber = this.parent.state.requestNumber
    if(this.parent.state.page > 0) {
      this.parent.setState({page: this.parent.state.page - 1}, () => this.parent.saveParams(requestNumber))
    } else if(this.parent.state.offset) {
      this.parent.getRecords(this.parent.state.offset - 1, this.parent.state.sheetsPerPage - 1)
    }
  }

  setFilter = async () => {
    try {
      let clipboard
      try {
        clipboard = await window.navigator.clipboard.readText()
      } catch(e) {
        alert('Clipboard Data Blocked, Please ask IT for help enabling it')
      }

      let saved = JSON.parse(clipboard)

      const { newState = {} } = this.parent.getCleanState()

      this.parent.setState({...newState, ...(saved)}, this.parent.getRecords)
    } catch (e) {
      alert('Clipboard Data does not contain a valid filter')
    }
  }

  render() {
    const { currentPage = 0, hasSort = false, onFirstPage = true, onLastPage = false, pages = 0 } = this.props

    return (
      <div className='d-flex justify-content-between flex-wrap flex-fill'>
        <div className="d-flex justify-content-between flex-wrap flex-fill">
          <div className="col-auto mb-2">
            <button
              className='btn btn-info'
              onClick={this.previousPage}
              disabled={onFirstPage}
            >
              Previous Page
            </button>
          </div>
          <div className="col-auto mb-2">
            <button
              className='btn btn-warning'
              onClick={this.firstPage}
              disabled={onFirstPage}
            >
              First Page
            </button>
          </div>
          <div className="col-auto mb-2">
            <button
              className='btn btn-warning'
              onClick={this.clearSort}
              disabled={hasSort}
            >
              Clear Sort
            </button>
          </div>
          <div className="col-auto mb-2">
            <button
              className='btn btn-light'
              onClick={this.setFilter}
            >
              Set Filters
            </button>
          </div>
        </div>
        <div className="d-flex justify-content-between align-items-center flex-wrap flex-grow-1">
          <div className='col-auto text-center text-info display-4 flex-grow-1 mb-2' style={{fontSize: '2rem'}}>
            <strong>
              Page {currentPage} of {pages}
            </strong>
          </div>
        </div>
        <div className="d-flex justify-content-between flex-wrap flex-fill">
          <div className="col-auto mb-2">
            <Tooltip
              content={
                [
                  <div key="normal"><i>Click</i> = Normal</div>,
                  <div key="link"><i>Ctrl + Click</i> = Link</div>,
                  <div key="query"><i>Ctrl + Shift + Click</i> = Query Params</div>
                ]
              }
            >
              <button
                className='btn btn-light'
                onClick={this.copyFilter}
              >
                Copy Filters
              </button>
            </Tooltip>
          </div>
          <div className="col-auto mb-2">
            <button
              className='btn btn-warning'
              onClick={this.clearFilters}
            >
              Clear Filters
            </button>
          </div>
          <div className="col-auto mb-2">
            <button
              className='btn btn-warning'
              onClick={this.lastPage}
              disabled={onLastPage}
            >
              Last Page
            </button>
          </div>
          <div className="col-auto mb-2">
            <button
              className='btn btn-info float-right'
              onClick={this.nextPage}
              disabled={onLastPage}
            >
              Next Page
            </button>
          </div>
        </div>
      </div>
    )
  }
}
