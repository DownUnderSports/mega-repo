import { lazy } from 'react'

const HomePage = lazy(() => import(/* webpackChunkName: "home-page", webpackPrefetch: true */ 'pages/home'))
const ProxyPage = lazy(() => import(/* webpackChunkName: "proxy-page", webpackPrefetch: true */ 'pages/proxy'))
// const NotFoundPage = lazy(async () => ({ default: ( await import(/* webpackChunkName: "not-found-page" */ 'react-component-templates/pages') ).NotFoundPage }))

const routes = [
  {
    path: '/my-info/:dusId',
    component: ProxyPage,
  },
  {
    path: '/my-info',
    component: HomePage,
  },
  {
    path: '/',
    exact: true,
    component: HomePage,
  },
  {
    component: ProxyPage
  }
]

export default routes
