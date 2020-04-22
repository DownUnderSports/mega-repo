import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Infokit from './information';

describe('Pages - Infokit', () => {
  const div = document.createElement('div');
  const createInfokit = ({...props}) => {
    ReactDOM.render(
      <Router>
        <Infokit {...props} />
      </Router>
    , div);
    return div.querySelector('p')
  }

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <Infokit />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
