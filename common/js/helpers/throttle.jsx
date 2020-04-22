import { debounce } from 'react-component-templates/helpers'

export default function throttle(func, interval = 300, shouldDebounce = false) {
  let lastCall = 0,
      debounced = shouldDebounce && debounce(func, interval);

  return function () {
    let now = (new Date()).getTime();
    if(now - lastCall < interval)
      return debounced && debounced.apply(this, arguments);

    lastCall = now;
    return func.apply(this, arguments)
  }
}
