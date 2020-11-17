import { lazy } from 'react'

export const ReleasesIndexPage = lazy(() => import(/* webpackChunkName: "releases-index-page", webpackPrefetch: true */ 'pages/releases/index'))
// export const UsersShowPage = lazy(() => import(/* webpackChunkName: "releases-show-page", webpackPrefetch: true */ 'pages/releases/show'))
