import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';

import InfokitForm from './infokit-form'

describe('common/js/components - InfokitForm', () => {
  const div = document.createElement('div');
  const createInfokitForm = ({...props}) => {
    ReactDOM.render(<InfokitForm {...props} />, div);
    return div.querySelector('p')
  }

  it('is snapshotable', () => {
    const tree = renderer
      .create(<InfokitForm />)
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
