import { lazy } from 'react'
export const SchoolsIndexPage = lazy(() => import(/* webpackChunkName: "schools-index-page" */ 'pages/schools/index'))
export const SchoolsShowPage = lazy(() => import(/* webpackChunkName: "schools-show-page" */ 'pages/schools/show'))
