import { lazy } from 'react'
import { NotFoundPage } from 'react-component-templates/pages'
import FindUserPage from 'common/js/pages/find-user'

const ContactPage = lazy(() => import(/* webpackChunkName: "contact-page" */ 'common/js/pages/contact'))
const DepartureChecklistPage = lazy(() => import(/* webpackChunkName: "departure-checklist-page" */ 'common/js/pages/departure-checklist'))
const EncryptedFileTestPage = lazy(() => import(/* webpackChunkName: "encrypted-file-test-page" */ 'common/js/pages/encrypted-file-test'))
const EventRegistrationPage = lazy(() => import(/* webpackChunkName: "event-registration-page" */ 'common/js/pages/event-registration'))
const EventResultsPage = lazy(() => import(/* webpackChunkName: "event-results-page" */ 'pages/event-results'))
const FrequentlyAskedQuestionsPage = lazy(() => import(/* webpackChunkName: "f-a-q-page" */ 'common/js/pages/frequently-asked-questions'))
const FundraisingIdeasPage = lazy(() => import(/* webpackChunkName: "fundraising-ideas-client-page" */ 'common/js/pages/fundraising-ideas'))
const HomePage = lazy(() => import(/* webpackChunkName: "home-page", webpackPrefetch: true */ 'common/js/pages/home'))
const InformationPage = lazy(() => import(/* webpackChunkName: "information-page" */ 'common/js/pages/information'))
const LegalDocumentsPage = lazy(() => import(/* webpackChunkName: "legal-requirements-page" */ 'common/js/pages/legal-documents'))
const MediaPage = lazy(() => import(/* webpackChunkName: "media-page" */ 'common/js/pages/media'))
const MeetingsShowPage = lazy(() => import(/* webpackChunkName: "meetings-show-page" */ 'common/js/pages/meetings/show'))
const OverPaymentPage = lazy(() => import(/* webpackChunkName: "over-payment-page" */ 'common/js/pages/over-payment'))
const OpenTryoutsPage = lazy(() => import(/* webpackChunkName: "open-tryouts-page" */ 'common/js/pages/open-tryouts'))
const AthleteFormPage = lazy(() => import(/* webpackChunkName: "athlete-form-page" */ 'common/js/pages/athlete-form'))
const NominationFormPage = lazy(() => import(/* webpackChunkName: "nomination-form-page" */ 'common/js/pages/nomination-form'))
// const OurStaffPage = lazy(() => import(/* webpackChunkName: "our-staff-page", webpackPrefetch: true */ 'common/js/pages/our-staff'))
const QrCodesPage = lazy(() => import(/* webpackChunkName: "qr-codes-page" */ 'common/js/pages/qr-codes'))
const ParticipantsPage = lazy(() => import(/* webpackChunkName: "participants-page" */ 'common/js/pages/participants'))
const PassportPage = lazy(() => import(/* webpackChunkName: "client-passport-page" */ 'common/js/pages/passport'))
const PaymentPage = lazy(() => import(/* webpackChunkName: "payment-page", webpackPrefetch: true */ 'common/js/pages/payment'))
const PrivacyPage = lazy(() => import(/* webpackChunkName: "privacy-page" */ 'common/js/pages/privacy'))
const RedeemTicketPage = lazy(() => import(/* webpackChunkName: "redeem-ticket-page" */ 'common/js/pages/redeem-ticket'))
const ReceiptPage = lazy(() => import(/* webpackChunkName: "receipt-page" */ 'common/js/pages/receipt'))
const RefundsPage = lazy(() => import(/* webpackChunkName: "refunds-page" */ 'common/js/pages/refunds'))
const SportsPage = lazy(() => import(/* webpackChunkName: "sports-page" */ 'common/js/pages/sports'))
const TermsPage = lazy(() => import(/* webpackChunkName: "terms-page" */ 'common/js/pages/terms'))
const ThankYouTicketTermsPage = lazy(() => import(/* webpackChunkName: "thank-you-ticket-terms-page" */ 'common/js/pages/thank-you-tickets'))
const ThankYouTicketGeneratorPage = lazy(() => import(/* webpackChunkName: "thank-you-ticket-generator-page" */ 'common/js/pages/thank-you-ticket-generator'))
const TravelInfoPage = lazy(() => import(/* webpackChunkName: "travel-info-page" */ 'common/js/pages/travel-info'))
const UniformOrderPage = lazy(() => import(/* webpackChunkName: "uniform-order-page" */ 'common/js/pages/uniform-order'))
const VideosPage = lazy(() => import(/* webpackChunkName: "videos-page" */ 'common/js/pages/videos'))

const routes = [
  {
    path: '/contact',
    component: ContactPage
  },
  {
    path: '/contact-us',
    component: ContactPage
  },
  // {
  //   path: '/our-staff',
  //   component: OurStaffPage,
  // },
  {
    path: '/encrypted',
    component: EncryptedFileTestPage,
  },
  {
    path: '/fundraising-ideas',
    component: FundraisingIdeasPage,
  },
  {
    path: '/fundraising_ideas',
    component: FundraisingIdeasPage,
  },
  {
    path: '/sports',
    component: SportsPage
  },
  {
    path: '/terms',
    component: TermsPage
  },
  {
    path: '/thank_you_tickets',
    component: ThankYouTicketTermsPage,
  },
  {
    path: '/thank-you-tickets',
    component: ThankYouTicketTermsPage,
  },
  {
    path: '/thank_you_ticket_generator/:userId?',
    component: ThankYouTicketGeneratorPage,
  },
  {
    path: '/thank-you-ticket-generator/:userId?',
    component: ThankYouTicketGeneratorPage,
  },
  {
    path: '/redeem-ticket/:ticketId?',
    component: RedeemTicketPage
  },
  {
    path: '/redeem-tickets/:ticketId?',
    component: RedeemTicketPage
  },
  {
    path: '/redeem_ticket/:ticketId?',
    component: RedeemTicketPage
  },
  {
    path: '/redeem_tickets/:ticketId?',
    component: RedeemTicketPage
  },
  {
    path: '/refunds',
    component: RefundsPage
  },
  {
    path: '/refund-policy',
    component: RefundsPage
  },
  {
    path: '/open-tryouts',
    component: OpenTryoutsPage
  },
  {
    path: '/athlete-form',
    component: AthleteFormPage
  },
  {
    path: '/departure-checklist/:userId?',
    component: DepartureChecklistPage
  },
  {
    path: '/deposit/:dusId([A-Za-z-]+)',
    component: PaymentPage
  },
  {
    path: '/deposit',
    component: PaymentPage
  },
  {
    path: '/infokit/:dusId([A-Za-z-]+)',
    component: InformationPage
  },
  {
    path: '/infokit',
    component: InformationPage
  },
  {
    path: '/media',
    component: MediaPage
  },
  {
    path: '/nomination-form',
    component: NominationFormPage
  },
  {
    path: '/payment/:dusId([A-Za-z-]+)',
    component: PaymentPage
  },
  {
    path: '/payment',
    component: PaymentPage
  },
  {
    path: '/payments/:id([0-9]+-[^-]+-.*)',
    component: ReceiptPage
  },
  {
    path: '/privacy',
    component: PrivacyPage
  },
  {
    path: '/privacy-policy',
    component: PrivacyPage
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
    path: '/meetings/:meetingId([0-9]+)',
    component: MeetingsShowPage
  },
  {
    path: '/uniform-order/:userId?',
    component: UniformOrderPage
  },
  {
    path: '/videos/:category([A-Za-z]{1,5}|[A-Za-z]{7,})?/:userId?',
    component: VideosPage
  },
  {
    path: '/participants',
    component: ParticipantsPage
  },
  {
    path: '/legal-documents/:userId?',
    component: LegalDocumentsPage
  },
  {
    path: '/over-payment/:userId?',
    component: OverPaymentPage
  },
  {
    path: '/travel-info/:userId?',
    component: TravelInfoPage
  },
  {
    path: '/event-registration/:userId?',
    component: EventRegistrationPage
  },
  {
    path: '/event-results/:sport',
    component: EventResultsPage
  },
  {
    path: '/passport/:userId?',
    component: PassportPage
  },
  {
    path: '/faq',
    component: FrequentlyAskedQuestionsPage
  },
  {
    path: '/frequently-asked-questions',
    component: FrequentlyAskedQuestionsPage
  },
  {
    path: '/:dusId([A-Za-z-]+)',
    component: FindUserPage
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
