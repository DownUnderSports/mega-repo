export const appPort = String(window.location.port || "3000")
export const pxyPort = /[1-9]0{3}/.test(appPort) ? +appPort + 100 : appPort
export const domain = `lvh.me:${pxyPort}`
export const target = `http://${domain}/`
