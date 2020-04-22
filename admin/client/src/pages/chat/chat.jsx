import { lazy } from 'react'
export const ChatIndexPage = lazy(() => import(/* webpackChunkName: "chat-index-page" */ 'pages/chat/index'))
export default ChatIndexPage
