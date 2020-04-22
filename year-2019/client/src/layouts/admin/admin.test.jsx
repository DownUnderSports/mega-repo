import React from 'react'
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Admin from './admin'

describe('common/js/components - Admin', () => {
  const div = document.createElement('div');

  const createAdmin = ({...props}) => {
    ReactDOM.render((
      <Router>
        <Admin {...props} />
      </Router>
    ), div);
    return div.querySelector('section.Admin')
  }

  it('renders a semantic header tag', () => {
    const rendered = createAdmin()
    expect(rendered).toBeTruthy()
    expect(rendered.tagName).toBe("SECTION")
  })

  it('contains a semantic main tag', () => {
    const rendered = createAdmin()
    const main = rendered.querySelector('main')
    expect(main).toBeTruthy()
    expect(main.tagName).toBe('MAIN')
  })

  it("binds a scroll event to the window")
  it("rebinds a slower debounce scroll event past a certain scroll point")

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <Admin />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
    setTimeout(() => {
      ReactDOM.unmountComponentAtNode(div);
    })
  })
})
