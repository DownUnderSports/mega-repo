import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import CheckIn from './check-in';

describe('Pages - CheckIn', () => {
  const div = document.createElement('div');
  const createCheckIn = ({...props}) => {
    ReactDOM.render(
      <Router>
        <CheckIn {...props} />
      </Router>
    , div);
    return div.querySelector('p')
  }

  it('is snapshotable', () => {
    const rand = Math.random

    Math.random = () => 0

    const tree = renderer
      .create(
        <Router>
          <CheckIn />
        </Router>
      )
      .toJSON();

    Math.random = rand

    expect(tree).toMatchSnapshot()
  })
})
