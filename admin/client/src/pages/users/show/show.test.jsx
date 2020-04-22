import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Show from './show';

describe('Pages - Admin::Users::Show', () => {
  const div = document.createElement('div');
  const createHome = ({...props}) => {
    ReactDOM.render(
      <Router>
        <Show {...props} />
      </Router>
    , div);
    return div.querySelector('p')
  }

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <Show />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
