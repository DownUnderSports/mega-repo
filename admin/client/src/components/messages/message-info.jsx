import React, { Component } from 'react';
import MessageForm from 'forms/message-form'

export default class MessageInfo extends Component {
  constructor(props) {
    super(props)
    this.state = { showForm: !this.props.id }
  }

  capitalize(str) {
    return str[0].toUpperCase() + str.slice(1)
  }

  openMessageForm = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.setState({ showForm: true })
  }

  onSuccess = (e) => {
    this.setState({ showForm: false })
    this.props.onSuccess && this.props.onSuccess(e)
  }

  onCancel = (e) => {
    this.setState({ showForm: false })
    this.props.onCancel && this.props.onCancel(e)
  }

  render() {
    const {
      category,
      created_at,
      id,
      message,
      type,
      user_id,
      categories = [],
      reasons = [],
      staff_name
    } = this.props || {}

    return this.state.showForm ? (
      <MessageForm
        id={ id }
        userId={ user_id }
        onSuccess={ this.onSuccess }
        onCancel={ this.onCancel }
        url={ this.props.url || '' }
        type={type}
        categories={categories}
        reasons={reasons}
        message={{ ...this.props }}
      />
    ) : (
      <div className="list-group-item clickable p-0 pb-2" onClick={this.openMessageForm}>
        <div className="col-12 border-bottom">
          <div className='row bg-secondary text-light'>
            <div className='col-3 border-right'>{created_at}</div>
            <div className='col border-left'>{ this.capitalize(category) } - {staff_name}</div>
          </div>
        </div>
        <div className="col-12 bg-dark text-white">
          {message}
        </div>
      </div>
    );
  }
}
