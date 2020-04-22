import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Index from './index';

describe('Pages - Admin::GCMRegistrations::Index', () => {
  const div = document.createElement('div');
  const createIndex = ({...props}) => {
    ReactDOM.render(
      <Router>
        <Index {...props} />
      </Router>
    , div);
    return div.querySelector('p')
  }

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <Index />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
