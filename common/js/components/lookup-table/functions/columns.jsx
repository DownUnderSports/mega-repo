export function resetColumns(e) {
  e.preventDefault()
  e.stopPropagation()
  const changed = {}, requestNumber = this.state.requestNumber

  for (var i = 0; i < this.headers.length; i++) {
    changed[`headers-${this.headers[i]}`] = false
  }
  this.setState(changed, () => this.saveParams(requestNumber))
}

export function toggleColumn(h) {
  const requestNumber = this.state.requestNumber

  this.setState({[`headers-${h}`]: !this.state[[`headers-${h}`]]}, () => this.saveParams(requestNumber))
}
