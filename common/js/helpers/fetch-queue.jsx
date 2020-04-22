class FetchQueue {
  constructor() {
    this.queue = []
    this.ran = []
    this.running = {}
    this.limit = 2
  }

  get runningCount() {
    return Object.keys(this.running || {}).length
  }

  update = () => window.document.dispatchEvent(new CustomEvent(
    'fetchQueueUpdate',
    {
      detail: undefined,
      bubbles: true,
      cancelable: false,
    }
  ))

  queueAvailable = () => this.queue.length && (this.runningCount < this.limit)

  nextItem = (item = false) => {
    item = item || this.queue.shift()
    this.running[item.key] = item
    item.ranAt = new Date()
    this.update()
    item.run().then(() => {
      item.completedAt = new Date()
      delete this.running[item.key]
      this.queueNext()
      this.ran.push(item)
      if(this.ran.length > 100) this.ran.shift()
      this.update()
    })
  }

  queueNext = () => setTimeout((() => this.queueAvailable() && this.nextItem()), 10)

  push = (obj) => {
    this.queue.push(obj)
    this.queueNext()
    this.update()
    return obj
  }

  setLimit = (ct) => this.limit = Number.parseInt(ct) || 1
}

const currentFetchQueue = new FetchQueue()

if(window.shouldMakeHydrationParamsPublic) {
  window.currentFetchQueue = currentFetchQueue
}

export default currentFetchQueue
