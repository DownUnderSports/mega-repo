import { cleanHistory, createParams, getCleanState, getRecords, onChange, saveParams, saveInStorage, subChange } from './filtering'
import { copyable, copyField } from './clipboard'
import { resetColumns, toggleColumn } from './columns'
import { currentPage, findLastPage, lastPage, pages } from './paging'
import { defaultFilterComponent, filterComponent, goToRecord, isActive, isDisabled, printValue, rowClassName } from './rendering'
import { checkSort, findSortKey, sort } from './sorting'
import { debounce } from 'react-component-templates/helpers';
import { phoneFormat } from 'react-component-templates/form-components';

export default class Constructor {
  static bindFunctions(cxt) {
    cxt.checkSort              = checkSort.bind(cxt)
    cxt.cleanHistory           = cleanHistory.bind(cxt)
    cxt.copyable               = copyable.bind(cxt)
    cxt.copyField              = copyField
    cxt.createParams           = createParams.bind(cxt)
    cxt.currentPage            = currentPage.bind(cxt)
    cxt.defaultFilterComponent = defaultFilterComponent.bind(cxt)
    cxt.filterComponent        = filterComponent.bind(cxt)
    cxt.findLastPage           = findLastPage
    cxt.findSortKey            = findSortKey.bind(cxt)
    cxt.getCleanState          = getCleanState.bind(cxt)
    cxt.getRecords             = getRecords.bind(cxt)
    cxt.goToRecord             = goToRecord.bind(cxt)
    cxt.isActive               = isActive.bind(cxt)
    cxt.isDisabled             = isDisabled
    cxt.lastPage               = lastPage.bind(cxt)
    cxt.onChange               = onChange.bind(cxt)
    cxt.pages                  = pages
    cxt.printValue             = printValue
    cxt.resetColumns           = resetColumns.bind(cxt)
    cxt.rowClassName           = rowClassName.bind(cxt)
    cxt.saveParams             = saveParams.bind(cxt)
    cxt.saveInStorage          = saveInStorage.bind(cxt)
    cxt.sort                   = sort.bind(cxt)
    cxt.subChange              = subChange.bind(cxt)
    cxt.toggleColumn           = toggleColumn.bind(cxt)
  }

  static initialSetup(cxt) {
    let query, searched, saved

    try {
      if(cxt.props.location.search) {
        query = new URLSearchParams(cxt.props.location.search)
        saved = {}
        if(query.get('setFilters') && (query.get('setFilters') === cxt.props.localStorageKey)) {
          searched = true
          saved = JSON.parse(decodeURIComponent(query.get('filtersValue')) || '{}')
        } else if(cxt.props.initialSearch) {
          for(let entry of query.entries()) {
            searched = true
            if(entry[0] === 'phone') {
              entry[1] = phoneFormat(entry[1])
            } else if(/^-?[0-9]+$/.test(entry[1])) {
              entry[1] = +entry[1]
            }
            saved[entry[0]] = entry[1]
          }
        }
      }
    } catch(e) {
      searched = void(0)
    }

    try {
      if(cxt.props.localStorageKey && !searched) {
        saved = JSON.parse(localStorage.getItem(cxt.props.localStorageKey) || '{}')
      }
    } catch(e) {
      saved = {}
    }

    cxt.state = { requestNumber: 0, records: [], recordsPerSheet: 10, sheetsPerPage: 10, offset: 0, page: 0, pages: 1, sort: [], transposed: false, ...(saved), onChange: debounce(() => cxt.getRecords(), 2500) }
    cxt.cleanHistory()
  }

  static run(cxt) {
    this.bindFunctions(cxt)
    this.initialSetup(cxt)
  }
}
