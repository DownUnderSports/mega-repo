import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Airports from './airports';

describe('Pages - Airports', () => {
  const div = document.createElement('div');
  const createAirports = ({...props}) => {
    ReactDOM.render(
      <Router>
        <Airports {...props} />
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
          <Airports />
        </Router>
      )
      .toJSON();

    Math.random = rand

    expect(tree).toMatchSnapshot()
  })
})
