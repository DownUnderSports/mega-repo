export function sort(e) {
  let target = e.target
  while ((target.tagName !== 'TH') && target.parentElement) {
    if(target.tagName === 'TR') return false
    target = target.parentElement
  }

  let val = target.innerText.replace(/(arrow|unfold|expand|\n).*/g, '').trim(), sort;

  if(val && this.headers.includes(val)) {
    const idx = this.findSortKey(val)
    if((idx !== false) && (e.ctrlKey || (this.state.sort.length === 1))) {
      sort = [ ...(this.state.sort) ]
      sort[idx] = {[val]: (sort[idx][val] === 'asc') ? 'desc' : 'asc' }
    } else {
      val = {[val]: 'asc'}
      if(e.ctrlKey) {
        sort = [...(this.state.sort || []), val]
      } else {
        sort = [ val ]
      }
    }
    this.setState({sort}, this.getRecords)
  }
}

export function checkSort(h) {
  const idx = this.findSortKey(h)
  // if(idx !== false) return (this.state.sort[idx][h] === 'asc') ? 'expand_more' : 'expand_less'
  if(idx !== false) return (this.state.sort[idx][h] === 'asc') ? 'arrow_downward' : 'arrow_upward'
  return 'unfold_more'
}

export function findSortKey(k) {
  for(let i = 0; i < this.state.sort.length; i++) {
    for(let h in this.state.sort[i]) {
      if(h === k) return i
    }
  }
  return false
}
