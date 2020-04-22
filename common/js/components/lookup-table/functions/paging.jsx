export function pages(total = 0, state = this.state) {
  console.log(total, state)
  const hundos = Math.floor((total || 0) / 100),
        tens = Math.ceil((total - hundos * 100) / state.recordsPerSheet)

  return (hundos * state.sheetsPerPage) + tens
}

export function currentPage(pages = this.state.pages) {
  return Math.min((this.state.page + 1) + (this.state.offset * this.state.sheetsPerPage), pages)
}

export function findLastPage(pages) {
  const offset = Math.floor(+(pages || 0) / this.state.sheetsPerPage),
        page = +(pages || 0) - (offset * this.state.sheetsPerPage) - 1
  if(page < 0) return [offset - 1, this.state.sheetsPerPage - 1]
  return [offset, page]
}

export async function lastPage(pages = this.state.pages) {
  const [offset, page] = this.findLastPage(pages)

  await this.getRecords(offset, page)
}
