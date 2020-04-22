import React, { Component } from 'react';
import Authenticated from 'components/authenticated';

import User from 'models/components/user'

import './home.css'

export default class HomePage extends Component {
  render() {
    return (
      <Authenticated>
        <div className="Page HomePage">
          <div className='row'>
            <div className="col">
              <User />
            </div>
          </div>
        </div>
      </Authenticated>
    );
  }
}
