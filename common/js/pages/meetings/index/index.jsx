import React, { Component } from 'react';

export default class MeetingsIndexPage extends Component {
  componentDidMount = () => {
    return this.props.history.push('/')
  }
}
