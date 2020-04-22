import React from 'react'
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Header from '../header'

describe('common/js/components - Header', () => {
  const div = document.createElement('div');

  const createHeader = ({...props}) => {
    ReactDOM.render((
      <Router>
        <Header {...props} />
      </Router>
    ), div);
    return div.querySelector('header')
  }

  it('renders a semantic header tag', () => {
    const rendered = createHeader()
    expect(rendered).toBeTruthy()
    expect(rendered.tagName).toBe("HEADER")
  })

  it('contains a nav tag', () => {
    const rendered = createHeader()
    const nav = rendered.querySelector('nav')
    expect(nav).toBeTruthy()
    expect(nav.tagName).toBe('NAV')
  })

  it('listens to window size changes to recalculate sticky top')

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <Header />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
    setTimeout(() => {
      ReactDOM.unmountComponentAtNode(div);
    })
  })
})
