import canUseDOM from 'common/js/helpers/can-use-dom'
let newPage = false
// fbq('track', 'PageView');
const createFbTracker = () => {
  /* eslint-disable-next-line */
  try{!function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version="2.0";n.queue=[];t=b.createElement(e);t.async=!0;t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window,document,"script","https://connect.facebook.net/en_US/fbevents.js");window.fbq("init",window.fbAppId || '2128450360577089')}catch(e){}
}
export default function dusPixelTracker(action, type) {
  try {
    if(!window.fbq) createFbTracker()
    return canUseDOM ? (newPage ? window.fbq(action, type) : (newPage = true)) : false
  } catch(e) {
    console.log(e.message)
  }
}
