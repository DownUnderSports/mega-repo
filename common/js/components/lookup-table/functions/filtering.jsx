export function createParams() {
  try {
    let filterParams = '', sortParams = '', objToStore = {sort: this.state.sort || []}
    for(let i = 0; i < this.headers.length; i++) {
      const param = this.headers[i]
      objToStore[`headers-${param}`] = !!this.state[`headers-${param}`]
      if(this.state[param]){
        objToStore[param] = this.state[param]
        filterParams = `${filterParams}&${encodeURIComponent(this.aliasFields[param] || param)}=${encodeURIComponent(this.state[param])}`
      }
    }

    for(let i = 0; i < this.additionalFilters.length; i++) {
      const param = this.additionalFilters[i]
      if(this.state[param]){
        objToStore[param] = this.state[param]
        filterParams = `${filterParams}&${encodeURIComponent(this.aliasFields[param] || param)}=${encodeURIComponent(this.state[param])}`
      }
    }

    if(this.props.computedFilters) {
      const addFill = this.props.computedFilters(this.state)
      for( let param in addFill ) {
        const v = addFill[param]
        objToStore[param] = v
        filterParams = `${filterParams}&${this.aliasFields[param] || param}=${v}`
      }
    }

    if(Array.isArray(this.state.sort)){
      for(let s = 0; s < this.state.sort.length; s++) {
        const o = this.state.sort[s]
        for(let h in o) {
          if(o.hasOwnProperty(h)) sortParams = `${sortParams}&sort[]=${this.aliasFields[h] || h}&directions[${this.aliasFields[h] || h}]=${o[h]}`
        }
      }
    }

    objToStore.page = +(this.state.page || 0)
    objToStore.offset = +(this.state.offset || 0)
    objToStore.recordsPerSheet = +(this.state.recordsPerSheet || 10)
    objToStore.sheetsPerPage = +(this.state.sheetsPerPage || 10)

    return [
      filterParams,
      sortParams,
      objToStore
    ]
  } catch(e) {
    console.error(e)
    return ['', '', {offset: 0, page: 0}]
  }
}

export function getCleanState() {
  const newState = {};
  let changed
  for(let i = 0; i < this.headers.length; i++) {
    changed = changed || !!(this.state[this.headers[i]])
    newState[this.headers[i]] = ''
  }
  return {
    changed,
    newState
  }
}

export async function getRecords(offset = 0, page = 0) {
  if(!this._isMounted) return false
  const requestNumber = this.state.requestNumber + 1

  offset = +(offset || 0)
  page = +(page || 0)

  await this.setStateAsync({loading: true, records: [], offset, page, requestNumber})
  try {

    const [filterParams, sortParams, objToStore] = this.createParams()

    const result = await this.fetchResource(`${this.url()}.json?page=${+(offset || 0)}${filterParams}${sortParams}`, { timeout: 5000 }),
          records = result[this.props.resultsKey || 'records'] || [],
          total = +(result[this.props.totalKey || 'total'] || 0)

    if(!this._isMounted) return false

    if(records && this.state.requestNumber === requestNumber) {
      this.saveInStorage(objToStore)

      const pages = this.pages(total)

      if(pages <= this.currentPage(pages)) {
        const [newOffset, newPage] = this.findLastPage(pages)

        offset = newOffset
        page = newPage
        if(!records.length) {
          if(total && (page || offset)) return await this.lastPage(pages)
          page = 0
          offset = 0
        }
      }

      await this.setStateAsync({
        loading: false,
        records,
        total,
        pages: this.pages(total),
        offset,
        page
      })
    } else {
      if(!this._isMounted) return false
      return await this.setStateAsync(this.defaultValue())
    }
  } catch(e) {
    console.error(e)
    if(!this._isMounted) return false
    return await this.setState(this.defaultValue())
  }
}

export function onChange(k, val) {
  if(this.state[k] !== val) this.setState({[k]: val}, this.state.onChange)
}

export function saveParams(requestNumber) {
  console.log(this.storageKey)
  if(this.storageKey) {
    const objToStore = this.createParams()[2]
    if(this.state.requestNumber === requestNumber) this.saveInStorage(objToStore)
  }
}

export function subChange(newState) {
  this.setState(newState, this.state.onChange)
}

const objStateUnclean = function objStateUnclean(obj) {
  for (let k in obj) {
    if (obj.hasOwnProperty(k)) {
      if(obj[k] && (!Array.isArray(obj[k]) || obj[k].length)) {
        return true
      }
    }
  }
  return false
}

export function cleanHistory() {
  const history = [...this.storageHistory]
  console.log('cleaning filter history:', history)

  for (let i = 0; i < history.length; i++) {
    if(!objStateUnclean(history[i])) history.splice(i, i)
  }

  this.storageHistory = history
}

export function saveInStorage(obj) {
  if(this.storageKey) {
    const history = [...this.storageHistory],
          str = JSON.stringify(obj || {}),
          unclean = (str !== '{}')
            && objStateUnclean(obj),
          fIndex = unclean
            && history.findIndex(o => JSON.stringify(o || {}) === str)

    if(fIndex) {
      if( fIndex !== -1 )  history.splice(fIndex, 1)

      history.unshift(obj)
      this.storageHistory = history

      localStorage.setItem(this.storageKey, str)
    } else if(!unclean) {
      localStorage.removeItem(this.storageKey)
    }
  }
}
