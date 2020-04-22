import React, { Component } from 'react'
//import authFetch from 'common/js/helpers/auth-fetch'
import { canUseDOM } from 'fbjs/lib/ExecutionEnvironment'

const FUNCTION_REGEX = /function\s*([\w\-$]+)?\s*\(/i,
      MAX_FAKE_STACK_SIZE = 10,
      ANONYMOUS_FUNCTION_PLACEHOLDER = "[anonymous]",
      caughtErrors = new WeakSet();
let shouldCatch = true

function stacktraceFromException(exception) {
  return exception.stack || exception.backtrace || exception.stacktrace
}

function generateStacktrace(e) {
  var stacktrace

  // Try to generate a real stacktrace (most browsers, except IE9 and below).
  try {
    if(e instanceof Error){
      stacktrace = stacktraceFromException(e)
    } else {
      throw new Error(e.message || "")
    }
  } catch (exception) {
    stacktrace = stacktraceFromException(exception)
  }

  if(stacktrace) {
    const splitStack = stacktrace.split("\n")
    var lastLine = splitStack[splitStack.length - 1]
  }

  // Otherwise, build a fake stacktrace from the list of method names by
  // looping through the list of functions that called this one (and skip
  // whoever called us).
  if (!stacktrace || (lastLine && /e\._wrapped\.e\._wrapped/.test(lastLine))) {
    var functionStack = []
    // eslint-disable-next-line no-caller
    var curr = arguments.callee.caller.caller
    while (curr && functionStack.length < MAX_FAKE_STACK_SIZE) {
      var fn = FUNCTION_REGEX.test(curr.toString()) ? RegExp.$1 || ANONYMOUS_FUNCTION_PLACEHOLDER : ANONYMOUS_FUNCTION_PLACEHOLDER
      functionStack.push(fn)
      curr = curr.caller
    }

    stacktrace = functionStack.join("\n")
  }

  return stacktrace
}

export async function logError(error, info, additional) {
  if(canUseDOM){

    const errorLog = {
      page: window.location.href,
      error: error.message,
      trace: generateStacktrace(error),
      componentstack: info && info.componentstack,
      logHistory: console.history || []
    }
    for(let p in navigator) errorLog[p] = navigator[p]

    errorLog.additional = additional

    if(!/^\s*Script\s+[Ee]rror\.\s*/.test(errorLog.error) && (!additional || (!/NS_ERROR/.test(additional.message)))) {
      try {
        await fetch('/api/errors', {
          method: 'POST',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify(errorLog)
        })
      } catch(err) {
        console.error(err)
      }
    }
    console.log(errorLog)
  }
}

function wrapErrors(func) {
  // Ensure we only wrap the function once.
  if (!func._wrapped) {
    func._wrapped = function () {
      if(shouldCatch){
        try{
          func.apply(this, arguments)
        } catch(e) {
          logError(e)
          throw e
        }
      } else {
        func.apply(this, arguments)
      }
    }
  }
  return func._wrapped
}

if(canUseDOM) {
  if (!window.atob) {
    shouldCatch = false
  // Disable catching on browsers that support HTML5 ErrorEvents properly.
  // This lets debug on unhandled exceptions work.
  } else if (window.ErrorEvent) {
    try {
      if (new window.ErrorEvent("test").colno === 0) {
        shouldCatch = false
      }
    } catch(e){
      console.log('Caught in IE shouldCatch test')
    }
  }

  const eTarget = window.EventTarget || window.Element
  if(eTarget && !!(eTarget.prototype.addEventListener)) {
    console.log('Overriding addEventListener')
    const addEventListener = eTarget.prototype.addEventListener
    eTarget.prototype.addEventListener = function (event, callback, bubble) {
      // console.log(this, event, callback, bubble)
      addEventListener.call(this, event, wrapErrors(callback), bubble)
    }
    const removeEventListener = eTarget.prototype.removeEventListener
    eTarget.prototype.removeEventListener = function (event, callback, bubble) {
      // console.log(this, event, callback, bubble)
      removeEventListener.call(this, event, callback && (callback._wrapped || callback), bubble)
    }
    console.log('calling error listener')
    window.addEventListener && window.addEventListener('error', (event) => {
      console.log('window error')
      try {
        let {error, message} = event;
        console.log('guard filter', error, caughtErrors.has(error), caughtErrors)
        console.log(error, caughtErrors.has(error), caughtErrors)

        if (error && caughtErrors.has(error)) {
          console.log('previously caught', error, error.stack)
          return true;
        }
        throw (error ? (caughtErrors.add(error) && error) : new Error(message))
      } catch(e) {
        logError(e, {
          componentstack: 'at Error Event Listener'
        }, {
          message: event.message,
          fileName: event.filename,
          line: event.lineno,
          col: event.colno
        })
      }
    })
  } else {
    logError({
      message: 'Browser Too Old!'
    })
  }
}

export default class ErrorBoundary extends Component {
  state = { hasError: false }

  componentDidCatch(error, info) {
    // You can also log the error to an error reporting service
    this.setState({
      hasError: true
    })
    logError(error, info);
  }

  hardRefresh(ev){
    try {
      ev.preventDefault();
      ev.stopPropagation()
    } catch(e) {
      console.error(e)
    }
    window.location.reload(true)
  }

  isUnsupported() {
    try {
      if(!window.navigator) return true;
      const ua = `${window.navigator.userAgent}`
      if(!/(Chrome|Safari|Firefox)/.test(ua)) return true;
      if(/(MSIE|Trident\/[0-7]|Chrome\/[0-4]|Firefox\/[0-4][0-2])/.test(ua)) return true;
      if(!(/Chrome/.test(ua)) && /Safari\/[0-6]0[0-2]/.test(ua)) return true;

    } catch(e) {
      return true
    }
  }

  render() {
    if (this.state.hasError) {
      if(this.isUnsupported()) {
        return (
          <div className="row m-5">
            <div className='col text-center'>
              <h1>Your Browser is too old</h1>
              <h3>
                Please upgrade to the latest Chrome, Firefox, Opera or Safari Browser.
              </h3>
              <p>
                <a href="https://www.computerhope.com/issues/ch001388.htm">
                  For help with/more info on upgrading your browser click here.
                </a>
              </p>
            </div>
          </div>
        )
      }
      // You can render any custom fallback UI
      return (
        <div className="row m-5">
          <div className='col text-center'>
            <h1>An Unexpected Error Has Occured</h1>
            <p>
              <a href={window.location.href} onClick={this.hardRefresh}>
                Click Here to try refreshing the page
              </a>
            </p>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
