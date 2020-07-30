const eventIsSupported = (() => {
  const TAGNAMES = {
    'select':'input',
    'change':'input',
    'submit':'form',
    'reset':'form',
    'error':'img',
    'load':'img',
    'abort':'img',
    'afterprint': 'window',
    'beforeprint': 'window'
  }
  return function eventIsSupported(ev) {
    const el = TAGNAMES[ev] === 'window' ? window : document.createElement(TAGNAMES[ev] || 'div'),
          eventName = 'on' + ev;
    let isSupported = (eventName in el);
    if (!isSupported) {
      if(el === window) {
        const cv = el[eventName]
        el[eventName] = undefined
        isSupported = el[eventName] === null
        el[eventName] = cv
      } else {
        el.setAttribute(eventName, 'return;');
        isSupported = typeof el[eventName] == 'function';
      }
    }
    return isSupported;
  }
})()

export default eventIsSupported
