import { NotFoundPage } from 'react-component-templates/pages'

import { AccountingIndexPage } from 'pages/accounting'
import { TravelingIndexPage } from 'pages/traveling'
import { AssignmentsIndexPage } from 'pages/assignments'
import { MailingsIndexPage, MailingsShowPage } from 'pages/mailings'
import { SchoolsIndexPage, SchoolsShowPage } from 'pages/schools'
import { UsersIndexPage, UsersShowPage } from 'pages/users'

import { lazy } from 'react'

const EncryptedFileTestPage = lazy(() => import('pages/encrypted-file-test'))

const routes = [
  {
    path: '/admin/accounting',
    component: AccountingIndexPage,
  },
  {
    path: '/admin/assignments',
    component: AssignmentsIndexPage,
  },
  {
    path: '/admin/traveling',
    component: TravelingIndexPage,
  },
  {
    path: '/admin/users/:id',
    component: UsersShowPage
  },
  {
    path: '/admin/users',
    component: UsersIndexPage
  },
  {
    path: '/admin/returned_mails/:id',
    component: MailingsShowPage
  },
  {
    path: '/admin/returned_mails',
    component: MailingsIndexPage
  },
  {
    path: '/admin/schools/:id',
    component: SchoolsShowPage
  },
  {
    path: '/admin/schools',
    component: SchoolsIndexPage
  },
  {
    path: '/admin/encrypted',
    component: EncryptedFileTestPage,
  },
  {
    path: '/admin/:id([A-Za-z-]+)',
    component: UsersShowPage
  },
  {
    path: '/admin/',
    exact: true,
    component: UsersIndexPage,
  },
  {
    path: '/accounting',
    component: AccountingIndexPage,
  },
  {
    path: '/traveling',
    component: TravelingIndexPage,
  },
  {
    path: '/:id([A-Za-z-]+)',
    component: UsersShowPage
  },
  {
    path: '/',
    exact: true,
    component: UsersIndexPage,
  },
  {
    component: NotFoundPage
  }
]

export default routes
