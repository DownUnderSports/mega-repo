// class AbortablePromise extends Promise {
//   get abort() {
//     return this._abortFunction
//   }
//
//   set abort(abortFunction) {
//     return this._abortFunction = abortFunction
//   }
//
//   get cancel() {
//     return this._cancelFunction
//   }
//
//   set cancel(cancelFunction) {
//     return this._cancelFunction = cancelFunction
//   }
//
//   constructor(func) {
//     let reject
//     const wrapped = (res, rej) => {
//       reject = rej
//       func(res, rej)
//     }
//     super(wrapped)
//     this.abort = reject
//     this.cancel = reject
//     return this
//   }
// }
//
// new AbortablePromise((res, rej) => {})
//
// try {
//   Object.defineProperty(
//     window,
//     'Promise',
//     {
//       get() { return AbortablePromise },
//       set(func) { console.info("Promise override attempted", func) }
//     }
//   )
// } catch(e) {
//   console.error(e)
//   window.Promise = AbortablePromise
// }
//
// export default AbortablePromise
