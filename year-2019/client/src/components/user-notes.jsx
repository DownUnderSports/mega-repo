import Messages from 'components/messages'

export default class UserNotes extends Messages {
  category() {
    return 'Notes';
  }

  type() {
    return 'note'
  }
}
