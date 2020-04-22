export function hasTouch() {
  try {
    return 'ontouchstart' in document.documentElement
           || navigator.maxTouchPoints > 0
           || navigator.msMaxTouchPoints > 0;
  } catch(e) {
    return false
  }
}

export function setHoverEvents(onHover, offHover, retries = 0) {
  return new Promise((res, rej) => {
    try {
      document.addEventListener('touchstart', onHover, true)
      document.addEventListener('mousemove', offHover, true)

      res(() => {
        document.removeEventListener('touchstart', onHover, true)
        document.removeEventListener('mousemove', offHover, true)
      })

    } catch(e) {
      if(retries < 6) {
        setTimeout(() => {
          res(setHoverEvents(onHover, offHover, retries + 1))
        }, 200 * retries)
      } else {
        rej(e)
      }
    }
  })
}
