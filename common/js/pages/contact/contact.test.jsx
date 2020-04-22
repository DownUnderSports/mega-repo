import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Contact from './contact';

describe('Pages - Contact', () => {
  const div = document.createElement('div');
  const createContact = ({...props}) => {
    ReactDOM.render(
      <Router>
        <Contact {...props} />
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
          <Contact />
        </Router>
      )
      .toJSON();

    Math.random = rand

    expect(tree).toMatchSnapshot()
  })
})
