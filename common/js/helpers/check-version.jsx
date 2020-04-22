//import authFetch from 'common/js/helpers/auth-fetch'
import canUseDOM from 'common/js/helpers/can-use-dom'

let pageLoaded, checking

async function runCheck(){
  if(!pageLoaded && !checking) {
    checking = true
    if(canUseDOM) {
      try {
        const result = await fetch('/api/version'),
              version = await result.text(),
              versionEl = document.getElementById('app-version')


        if(version && versionEl && version !== versionEl.value) return window.location.reload(true)
      } catch(_) {
        return window.location.reload(true)
      }
      checking = false
      pageLoaded = true
      setTimeout(function(){ pageLoaded = false }, 5 * 60 * 1000)
    } else {
      checking = false
      setTimeout(runCheck, 1000)
    }
  }
}

export default async function checkVersion(force) {
  if(force) pageLoaded = false;
  return await runCheck()
}
