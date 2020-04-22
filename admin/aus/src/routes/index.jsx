import { lazy } from 'react'

const AirportsPage = lazy(() => import(/* webpackChunkName: "airports-page", webpackPrefetch: true */ 'pages/airports'))
const CheckInPage = lazy(() => import(/* webpackChunkName: "check-in-page", webpackPrefetch: true */ 'pages/check-in'))
const HomePage = lazy(() => import(/* webpackChunkName: "home-page", webpackPrefetch: true */ 'pages/home'))
const NotFoundPage = lazy(async () => ({ default: ( await import(/* webpackChunkName: "not-found-page" */ 'react-component-templates/pages') ).NotFoundPage }))

const routes = [
  {
    path: '/airports',
    component: AirportsPage,
  },
  {
    path: '/check-in',
    component: CheckInPage,
  },
  {
    path: '/',
    exact: true,
    component: HomePage,
  },
  {
    component: NotFoundPage
  }
]

export default routes
