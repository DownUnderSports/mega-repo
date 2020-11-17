import React, { Component } from 'react'
import PropTypes from 'prop-types'
import { debounce } from 'react-component-templates/helpers'
import quickSort from 'common/js/helpers/quick-sort-object'

export default class SortableTable extends Component {
  static propTypes = {
    headers:       PropTypes.array,
    headerAliases: PropTypes.object,
    data:          PropTypes.array,
    limit:         PropTypes.number,
    children:      PropTypes.any
  }
  constructor(props){
    super(props)
    const data = quickSort(props.data, props.headers[0])
    this.state = {
      headers: [...(props.headers)],
      headerAliases: this.props.headerAliases || {},
      data: data.slice(0, props.limit || 100),
      currentPage: 0,
      pages: Math.ceil(data.length / (props.limit || 100)),
      fullData: data,
      originalData: data,
      sorting: [{value: props.headers[0], reversed: false, idx: 0}],
      reversed: false,
      limit: props.limit || 100
    }
    this.sortBy = this.sortBy.bind(this)
    this.debouncedOnChange = this.debouncedOnChange.bind(this)
  }

  componentDidMount(){
    this.debouncedFilter = debounce(this.filter, 200);
  }

  componentWillReceiveProps({headers, data, limit}){
    limit = +(limit || this.state.limit || 100)
    data = quickSort(data, headers[0])
    this.setState({
      headers: [...(headers)],
      data: data.slice(0, limit),
      currentPage: 0,
      pages: Math.ceil(data.length / limit),
      fullData: data,
      originalData: data,
      sorting: [{value: headers[0], reversed: false, idx: 0}],
      reversed: false,
      limit: limit
    })
  }

  checkSort = (h) => {
    const idx = this.findSortKey(h)
    // if(idx !== false) return (this.state.sort[idx][h] === 'asc') ? 'expand_more' : 'expand_less'
    if(idx !== false) return this.state.sorting[idx].reversed ? 'arrow_upward' : 'arrow_downward'
    return 'unfold_more'
  }

  findSortKey = (k) => {
    for(let i = 0; i < this.state.sorting.length; i++) {
      if(this.state.sorting[i].value === k) return i
    }
    return false
  }

  runSort(data, by, reversed = false){
    const sorted = quickSort(data, by)
    return reversed ? sorted.reverse() : sorted
  }

  sortBy(idx, multi = false){
    let val = this.state.headers[idx]
    if(multi){
      idx = [...this.state.sorting.filter(i => i.value !== val), {value: val, reversed: !((this.state.sorting.find(i => i.value === val) || {reversed: true}).reversed), idx}]
    } else {
      const found = this.state.sorting.find(i => i.value === val)
      idx = [{value: val, reversed: found && !found.reversed, idx}]
    }
    const rev = (idx.length === 1 && idx[0].reversed)
    const data = this.runSort(this.state.fullData, (idx.length === 1 ? idx[0].value : idx), rev)
    this.setState({
      sorting: idx,
      data: data.slice(0, this.state.limit),
      currentPage: 0,
      fullData: data
    })
  }

  filter(e){
    // eslint-disable-next-line
    const data = e.target.value ? this.state.originalData.filter(datum => Object.values(datum).find(v => new RegExp(e.target.value.replace(/[\/\(\)\[\]\\]/g, '\\$&'), "i").test(v))) : this.state.originalData
    this.setState({
      data: data.slice(0, this.state.limit),
      currentPage: 0,
      fullData: data,
      pages: Math.ceil(data.length / this.state.limit)
    })
  }

  setPage(page = 0){
    const base = (page * this.state.limit)
    this.setState({
      data: this.state.fullData.slice(base, base + this.state.limit),
      currentPage: page,
    })
  }

  debouncedOnChange(e){
    e.persist()
    this.debouncedFilter(e)
  }

  pagination() {
    return (
      <div className="btn-toolbar form-group justify-content-between col" role="toolbar" aria-label="Table Pagination">
        {
          (
            (this.state.pages > 5)
            &&
            <div className="btn-group" role="group" aria-label="Beginning of List">
              <button type="button" className="btn btn-secondary" onClick={() => this.setPage(0)}>1</button>
              {
                Array(2).fill().map((_, i) => (
                  <button key={i} type="button" className="btn btn-secondary" onClick={() => this.setPage(1 + i)}>{2 + i}</button>
                ))
              }
            </div>
          ) || <span></span>
        }
        <div className="btn-group" role="group" aria-label="Navigate List">
          {
            (this.state.currentPage > 0) &&
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => this.setPage(this.state.currentPage - 1)}>
              Previous
            </button>
          }
          {
            ((this.state.currentPage + 1) < this.state.pages) &&
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => this.setPage(this.state.currentPage + 1)}>
              Next
            </button>
          }
        </div>
        {
          (
            (this.state.pages > 5)
            &&
            <div className="btn-group" role="group" aria-label="End Of List">
              {
                Array(2).fill().map((_, i) => (
                  <button key={i} type="button" className="btn btn-secondary" onClick={() => this.setPage(this.state.pages - (3-i))}>{this.state.pages - (2-i)}</button>
                ))
              }
              <button type="button" className="btn btn-secondary" onClick={() => this.setPage(this.state.pages - 1)}>{this.state.pages}</button>
            </div>
          ) || <span></span>
        }
      </div>
    )
  }

  render() {
    const pageButtons = this.pagination()
    return (<section className='row'>
      <div className="col-md-6">
        {this.props.children}
      </div>
      <div className="col-md-6 float-right form-group">
        <label htmlFor="table_filter" className='form-control-label'>
          Filter Results:
        </label>
        <input
          type="text"
          onChange={this.debouncedOnChange}
          className='form-control'
          id="table_filter"
        />
        <small className="form-text">Type Here to filter on any column below</small>
      </div>
      {pageButtons}
      <div className="col-12">
        <table className='table table-bordered table-striped'>
          <thead className='thead-inverse'>
            <tr className='clickable'>
              {
                this.state.headers.map((h, i) => (
                  <th onClick={(e) => this.sortBy(i, e.shiftKey || e.ctrlKey || e.metaKey )} key={i}>
                    <span className='pr-3 text-capitalize'>
                      {this.state.headerAliases[h] || h.split("_").join(' ')}
                    </span>
                    <i className="material-icons">
                      {this.checkSort(h)}
                    </i>
                  </th>
                ))
              }
            </tr>
          </thead>
          <tbody>
            {
              this.state.data.map((datum, i) => (<tr key={`row_${i}`}>
                {
                  this.state.headers.map((header, j) => (<td key={(i+1)*j}>
                    {datum[header]}
                  </td>))
                }
              </tr>))
            }
          </tbody>
        </table>
      </div>
      {pageButtons}
    </section>)
  }
}
