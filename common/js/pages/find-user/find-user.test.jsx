import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import FindUser from './find-user';

describe('Pages - FindUser', () => {
  const div = document.createElement('div');
  const createInfokit = (params = {}) => {
    ReactDOM.render(
      <Router>
        <FindUser
          match={{
            params: {
              ...params
            }
          }}
        />
      </Router>
    , div);
    return div.querySelector('p')
  }

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <FindUser />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
