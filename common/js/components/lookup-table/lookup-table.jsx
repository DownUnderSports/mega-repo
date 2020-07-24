import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import Tooltip from 'common/js/components/tooltip'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { Buttons, Colors, HeaderToggle, SpecialCharacters, TableFooter, VisibleColumns } from './components'
import Constructor from './functions/constructor'
import { withRouter } from 'react-router-dom';

import './lookup-table.css'

const headerStyle = {display: 'flex', flexFlow: 'row nowrap', justifyContent: 'space-between', position: 'relative'}

class LookupTable extends AsyncComponent {
  get headers() {
    return this.props.headers || []
  }

  get filteredHeaders() {
    return this.headers.filter((h) => !this.state[`headers-${h}`])
  }

  get aliasFields() {
    return this.props.aliasFields || {}
  }

  get additionalFilters() {
    return this.props.additionalFilters || []
  }

  get idKey() {
    return this.props.idKey || 'id'
  }

  get tooltips() {
    return this.props.tooltips || {}
  }

  get storageKey() {
    return this.props.localStorageKey || ''
  }

  get historyKey() {
    return this.storageKey && `${this.storageKey}--History`
  }

  get activeKey() {
    return this.storageKey && `${this.storageKey}--Active`
  }

  get storageHistory() {
    if(this._storageHistory) return this._storageHistory
    try {
      this._storageHistory = this.historyKey ? JSON.parse(localStorage.getItem(this.historyKey) || '[]') : []
    } catch(e) {
      this._storageHistory = []
    }
    return this._storageHistory
  }

  set storageHistory(arr){
    this._storageHistory = [...(arr || [])]
    this.storageKey && localStorage.setItem(this.historyKey, JSON.stringify(this._storageHistory.slice(0, 10)))
    return this._storageHistory
  }

  constructor(props) {
    super(props)
    Constructor.run(this)
  }

  afterMount = async () => {
    await this.getRecords(+(this.state.offset || 0), +(this.state.page || 0))
  }

  defaultValue = () => ({
    loading: false
  })

  toggleTransposed = () => this.setState({ transposed: !this.state.transposed })

  setRecordsPerPage = async (ev) => {
    const recordsPerSheet = +ev.currentTarget.value || 10,
          sheetsPerPage   = 100 / recordsPerSheet

    if((recordsPerSheet === this.state.recordsPerSheet) || (100 % recordsPerSheet)) return false

    const newState = { recordsPerSheet, sheetsPerPage, page: Math.floor((this.state.page || 0) * (this.state.recordsPerSheet/recordsPerSheet)) }

    newState.pages = this.pages(this.state.total, newState)

    console.log(newState)

    await this.setStateAsync(newState)

    this.saveParams(this.state.requestNumber)
  }

  options = [ 2, 5, 10, 20, 25, 50, 100 ].map(v => <option key={v} value={v}># per Page: {v}</option>)

  render() {
    const currentPage = this.currentPage(),
          onLastPage = !!(currentPage >= +(this.state.pages || 0)),
          onFirstPage = (!this.state.page && !this.state.offset),
          recordsPerSheet = this.state.recordsPerSheet || 10

    return (
      <div className={`lookup-table-wrapper ${this.props.className || ''}`}>
        <div className="row">
          <Buttons
            parent={this}
            renderButtons={this.props.renderButtons}
            location="top"
          />
          <div className="col-12">
            <div className="row">
              <div className="col-lg-5">
                <VisibleColumns parent={this} />
              </div>
              <div className="col-lg-4">
                <SpecialCharacters />
              </div>
              <div className="col-lg-3">
                <Colors colors={this.props.colors || []} />
              </div>
            </div>
          </div>
          <div className="col-md-6">
            <div className="row">
              <HeaderToggle toggleColumn={this.toggleTransposed} checked={this.state.transposed} header='Transpose Table' />
            </div>
          </div>
          <div className="col-md-6">
            <select name="recordsPerSheet" className="form-control" value={recordsPerSheet} onChange={this.setRecordsPerPage}>
              { this.options }
            </select>
          </div>
          <div className="col">
            <table className={`table table-striped table-hover table-bordered table-secondary mb-0 table-transposable ${this.state.transposed ? 'table-flipped' : ''}`}>
              <thead className="thead-dark">
                <tr className='clickable text-info' onClick={this.sort}>
                  {
                    this.filteredHeaders.map((h, k) => (
                      <th className='text-warning no-wrap' scope='col' key={k}>
                        <span style={headerStyle}>
                          <Tooltip
                            content={this.tooltips[h] || h}
                            fixed
                          >
                            {h === 'category_type' ? 'category' : h}
                          </Tooltip>
                          <i className="material-icons">
                            {this.checkSort(h)}
                          </i>
                        </span>
                      </th>
                    ))
                  }
                </tr>
                <tr>
                  {
                    this.filteredHeaders.map((h, k) => (
                      <th scope='col' key={k}>
                        { this.filterComponent(h) }
                      </th>
                    ))
                  }
                </tr>
              </thead>
              <tbody>
                {
                  this.state.records.slice(this.state.page * recordsPerSheet, (this.state.page * recordsPerSheet) + recordsPerSheet).map((record, sk) => (
                    <tr className={this.rowClassName(record, this.isActive(record))} key={sk} onClick={(e) => this.goToRecord(e, record)}>
                      {
                        this.filteredHeaders.map((h, k) => (
                          <td key={`${sk}.${k}`} data-id={record[this.idKey]}>
                            {
                              this.copyable(h) ? (
                                <span className='copyable' onClick={this.copyField}>
                                  {this.printValue(record[this.aliasFields[h] || h])}
                                </span>
                              ) : this.printValue(record[this.aliasFields[h] || h])
                            }
                          </td>
                        ))
                      }
                    </tr>
                  ))
                }
              </tbody>
            </table>
            {
              this.state.loading ? (
                <JellyBox />
              ) : ''
            }
            <div className="w-100 bg-dark p-2 form-group table-footer-sticky">
              <TableFooter
                currentPage={currentPage}
                onFirstPage={onFirstPage}
                onLastPage={onLastPage}
                pages={this.state.pages}
                hasSort={!this.state.sort.length}
                parent={this}
              />
            </div>
          </div>
          <Buttons
            parent={this}
            renderButtons={this.props.renderButtons}
            location="bottom"
          />
        </div>
      </div>
    );
  }
}

export default withRouter(LookupTable)
