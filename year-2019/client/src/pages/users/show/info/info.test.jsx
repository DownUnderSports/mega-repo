import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Info from './info';

describe('Pages - Admin::Users::Show::Info', () => {
  const div = document.createElement('div');
  const createHome = ({...props}) => {
    ReactDOM.render(
      <Router>
        <Info {...props} />
      </Router>
    , div);
    return div.querySelector('p')
  }

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <Info />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
