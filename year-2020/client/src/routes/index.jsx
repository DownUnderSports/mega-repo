import { NotFoundPage } from 'react-component-templates/pages'

import { AccountingIndexPage } from 'pages/accounting'
import { TravelingIndexPage } from 'pages/traveling'
import { AssignmentsIndexPage } from 'pages/assignments'
import { MailingsIndexPage, MailingsShowPage } from 'pages/mailings'
import { FundraisingIdeasIndexPage, FundraisingIdeasShowPage } from 'pages/fundraising-ideas'
import { SchoolsIndexPage, SchoolsShowPage } from 'pages/schools'
import { UsersIndexPage, UsersShowPage } from 'pages/users'

import { lazy } from 'react'

const CalendarPage = lazy(() => import('pages/calendar'))
const EncryptedFileTestPage = lazy(() => import('pages/encrypted-file-test'))
const TermsPage = lazy(() => import('pages/terms'))
const PrivacyPage = lazy(() => import('pages/privacy'))
const TravelGiveawaysTermsPage = lazy(() => import('pages/travel-giveaways'))
const QrCodesPage = lazy(() => import('common/js/pages/qr-codes'))

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
    path: '/admin/fundraising_ideas/:id',
    component: FundraisingIdeasShowPage
  },
  {
    path: '/admin/fundraising_ideas',
    component: FundraisingIdeasIndexPage
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
    path: '/admin/terms',
    component: TermsPage,
  },
  {
    path: '/admin/privacy',
    component: PrivacyPage
  },
  {
    path: '/admin/travel_giveaways',
    component: TravelGiveawaysTermsPage,
  },
  {
    path: '/admin/travel-giveaways',
    component: TravelGiveawaysTermsPage,
  },
  {
    path: '/admin/thank_you_tickets',
    component: TravelGiveawaysTermsPage,
  },
  {
    path: '/admin/thank-you-tickets',
    component: TravelGiveawaysTermsPage,
  },
  {
    path: '/admin/calendar',
    component: CalendarPage,
  },
  {
    path: '/admin/qr-code',
    component: QrCodesPage,
  },
  {
    path: '/admin/qr-codes',
    component: QrCodesPage,
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
    path: '/calendar',
    component: CalendarPage,
  },
  {
    path: '/terms',
    component: TermsPage,
  },
  {
    path: '/travel_giveaways',
    component: TravelGiveawaysTermsPage,
  },
  {
    path: '/travel-giveaways',
    component: TravelGiveawaysTermsPage,
  },
  {
    path: '/thank_you_tickets',
    component: TravelGiveawaysTermsPage,
  },
  {
    path: '/thank-you-tickets',
    component: TravelGiveawaysTermsPage,
  },
  {
    path: '/traveling',
    component: TravelingIndexPage,
  },
  {
    path: '/qr-code',
    component: QrCodesPage,
  },
  {
    path: '/qr-codes',
    component: QrCodesPage,
  },
  {
    path: '/fundraising_ideas/:id',
    component: FundraisingIdeasShowPage
  },
  {
    path: '/fundraising_ideas',
    component: FundraisingIdeasIndexPage
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
