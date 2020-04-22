import Messages from 'components/messages'

export default class UserContactHistory extends Messages {
  category() {
    return 'Contact History';
  }

  type() {
    return 'history'
  }
}
