import 'helpers/inject-global'
import * as serviceWorker from './serviceWorker';


// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA

window.originalHTML = document.getElementById('root').innerHTML.replace(/class=(["'])container(.*)"/, 'class=$1$2');

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
    await import(/* webpackChunkName: "auth-fetch", webpackPreload: true */ 'helpers/auth-fetch')

    const React = (await import(/* webpackChunkName: "react", webpackPreload: true */ 'react')).default
    const ReactDOM = (await import(/* webpackChunkName: "react-dom", webpackPreload: true */ 'react-dom')).default


    const App = (await import(/* webpackChunkName: "app", webpackPreload: true */ 'App')).default
    await import(/* webpackChunkName: "atom-loader", webpackPreload: true */ 'load-awesome-react-components/dist/ball/atom.css')
    await import(/* webpackChunkName: "jelly-box-loader", webpackPreload: true */ 'load-awesome-react-components/dist/square/jelly-box.css')
    await import(/* webpackChunkName: "component-templates-css", webpackPreload: true */ 'react-component-templates/css/index.css')

    await import(/* webpackChunkName: "index-css", webpackPreload: true */ './index.css')

    window.ssrHydrationParams = {}

    ReactDOM.render(<App />, document.getElementById('root'));

    serviceWorker.register();
  } catch (e) {
    console.log(e)
  }
})()
