import { lazy } from 'react'
export const UsersIndexPage = lazy(() => import(/* webpackChunkName: "users-index-page", webpackPrefetch: true */ 'pages/users/index'))
export const UsersShowPage = lazy(() => import(/* webpackChunkName: "users-show-page", webpackPrefetch: true */ 'pages/users/show'))
