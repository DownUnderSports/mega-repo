const proxy = require('http-proxy-middleware');
const path = require('path');
const fs = require('fs');
const paths = require('react-scripts/config/paths');
const main_port = +(process.env.PORT || 3000)
const pxy_port = main_port + 100
const domain = `${process.env.HOST || 'lvh.me'}:${pxy_port}`
const target = `http://${domain}/`

const mayProxy = (pathname) => {
  const maybePublicPath = path.resolve(paths.appPublic, pathname.slice(1));
  const isPublicFileRequest = fs.existsSync(maybePublicPath);
  const isWdsEndpointRequest = pathname.startsWith('/sockjs-node'); // used by webpackHotDevClient
  const isJSChunk = pathname.endsWith('.chunk.js')
  const isStatic = /static\//.test(pathname)
  return !(isPublicFileRequest || isWdsEndpointRequest || isJSChunk || isStatic);
}

const context = (pathname, req) => {
  return req.method !== 'GET' ||
  (
    mayProxy(pathname)
    && req.headers.accept
    && (req.headers.accept.indexOf('text/html') === -1)
    // && !(/\*\/\*/.test(req.headers.accept))
  )
}

const getPathName = (req) =>
  req._parsedUrl
    ? req._parsedUrl.pathname
    : String(req.originalUrl || req.url || '/').split("?")[0] || "/"


const onProxyReq = (req) => {
  if (req.getHeader('origin')) req.setHeader('origin', target)
}

const proxyConfig = {
  target,
  logLevel: 'silent',
  changeOrigin: true,
  context,
  onProxyReq,
  secure: false,
  ws: true,
  xfwd: true
}

module.exports = function(app) {
  app.use(proxy('/rails', {
    target,
    changeOrigin: true,
  }));

  // proxy websocket
  app.use(proxy('/cable', {
    target: `ws://${domain}/`,
    changeOrigin: true,
    ws: true,
  }));

  // app.use((req, res, next) => {
  //   // next()
  //   context(getPathName(req), req)
  //     ? proxy({ target })(req, res, next)
  //     : next()
  //   // proxy(context, proxyConfig)(req, res, next)
  // })
  app.use(proxy(context, proxyConfig))
};
