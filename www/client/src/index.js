import 'react-app-polyfill/ie9'
(async () => {
  try {
    try {
      if(!('signal' in new Request(''))) {
        throw new Error("Needs Polyfill")
      }
    } catch(_) {
      window.fetch = (await import(/* webpackChunkName: "fetch-polyfill", webpackPrefetch: true */ 'whatwg-fetch')).fetch
    }
    console.log("made it past fetch")

    await import(/* webpackChunkName: "raf-polyfill", webpackPreload: true */ 'raf/polyfill')
    console.log("made it past raf")
    await import(/* webpackChunkName: "main-polyfills", webpackPreload: true */ 'polyfills')
    console.log("made it past polyfills")
    await import(/* webpackChunkName: "abortcontroller-polyfill", webpackPreload: true */ 'abortcontroller-polyfill')
    console.log("made it past abortcontroller")
    await import(/* webpackChunkName: "auth-fetch", webpackPreload: true */ 'common/js/helpers/auth-fetch')
    console.log("made it past auth-fetch")

    const React = (await import(/* webpackChunkName: "react", webpackPreload: true */ 'react')).default
    const ReactDOM = (await import(/* webpackChunkName: "react-dom", webpackPreload: true */ 'react-dom')).default

    const SiteRouter = (await import(/* webpackChunkName: "site-router", webpackPreload: true */ './site-router')).default

    console.log("Loaded components")

    await import(/* webpackChunkName: "index-css", webpackPreload: true */ './index.css')
    await import(/* webpackChunkName: "atom-loader", webpackPreload: true */ 'load-awesome-react-components/dist/ball/atom.css')
    await import(/* webpackChunkName: "jelly-box-loader", webpackPreload: true */ 'load-awesome-react-components/dist/square/jelly-box.css')
    await import(/* webpackChunkName: "component-templates-css", webpackPreload: true */ 'react-component-templates/css/index.css')

    try {
      window.shouldMakeHydrationParamsPublic = +(new URLSearchParams(window.location.search).get('rendering_no_cache')) === 1
    } catch(_) {
      window.shouldMakeHydrationParamsPublic = false
    }

    try {
      const hydrateHolder = document.getElementById('ssr-hydration-params')
      if(hydrateHolder) {
        window.ssrHydrationParams = JSON.parse(hydrateHolder.innerHTML)
        hydrateHolder.parentElement.removeChild(hydrateHolder)
      }
    } catch(_) {
      window.ssrHydrationParams = {}
    }

    window.ssrHydrationParams = window.ssrHydrationParams || {}

    ReactDOM[document.getElementById("dus-site-outer-wrapper") ? 'hydrate' : 'render'](<SiteRouter />, document.getElementById('root'))
  } catch (e) {
    console.log(e)
  }
})()


// import * as serviceWorker from './serviceWorker'





// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: http://bit.ly/CRA-PWA
// serviceWorker.unregister()
