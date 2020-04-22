import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Home from './home';

describe('Pages - Home', () => {
  const div = document.createElement('div');
  const createHome = ({...props}) => {
    ReactDOM.render(
      <Router>
        <Home {...props} />
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
          <Home />
        </Router>
      )
      .toJSON();

    Math.random = rand

    expect(tree).toMatchSnapshot()
  })
})
