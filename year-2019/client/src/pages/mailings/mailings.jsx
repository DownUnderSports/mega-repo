import { lazy } from 'react'
export const MailingsIndexPage = lazy(() => import(/* webpackChunkName: "mailings-index-page" */ 'pages/mailings/index'))
export const MailingsShowPage = lazy(() => import(/* webpackChunkName: "mailings-show-page" */ 'pages/mailings/show'))
