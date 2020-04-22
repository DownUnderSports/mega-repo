(async () => {
  try {

    try {
      if(!('signal' in new Request(''))) {
        throw new Error("Needs Polyfill")
      }
    } catch(_) {
      window.fetch = (await import(/* webpackChunkName: "fetch-polyfill", webpackPrefetch: true */ 'whatwg-fetch')).fetch
    }

    await import(/* webpackChunkName: "site-polyfills", webpackPreload: true */ 'polyfills')
    await import(/* webpackChunkName: "abortcontroller-polyfill", webpackPreload: true */ 'abortcontroller-polyfill')
    await import(/* webpackChunkName: "auth-fetch", webpackPreload: true */ 'common/js/helpers/auth-fetch')

    const React = (await import(/* webpackChunkName: "react", webpackPreload: true */ 'react')).default
    const ReactDOM = (await import(/* webpackChunkName: "react-dom", webpackPreload: true */ 'react-dom')).default


    const AdminRouter = (await import(/* webpackChunkName: "admin-router", webpackPreload: true */ './admin-router')).default

    await import(/* webpackChunkName: "index-css", webpackPreload: true */ './index.css')
    await import(/* webpackChunkName: "atom-loader", webpackPreload: true */ 'load-awesome-react-components/dist/ball/atom.css')
    await import(/* webpackChunkName: "jelly-box-loader", webpackPreload: true */ 'load-awesome-react-components/dist/square/jelly-box.css')
    await import(/* webpackChunkName: "component-templates-css", webpackPreload: true */ 'react-component-templates/css/index.css')
    await import(/* webpackChunkName: "ring-central", webpackPreload: true */ 'common/js/helpers/ring-central')

    window.ssrHydrationParams = {}

    ReactDOM.render(<AdminRouter />, document.getElementById('root'))
  } catch (e) {
    console.log(e)
  }
})()
