import Messages from 'components/messages'

export default class UserContactAttempts extends Messages {
  category() {
    return 'Contact Attempts';
  }

  type() {
    return 'attempt'
  }
}
