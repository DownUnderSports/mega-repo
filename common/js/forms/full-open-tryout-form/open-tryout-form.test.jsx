import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';

import OpenTryoutForm from './open-tryout-form'

describe('common/js/components - OpenTryoutForm', () => {
  const div = document.createElement('div');
  const createOpenTryoutForm = ({...props}) => {
    ReactDOM.render(<OpenTryoutForm {...props} />, div);
    return div.querySelector('p')
  }

  it('is snapshotable', () => {
    const tree = renderer
      .create(<OpenTryoutForm />)
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
