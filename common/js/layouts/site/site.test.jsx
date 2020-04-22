import React from 'react'
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Site from './site'

describe('common/js/components - Site', () => {
  const div = document.createElement('div');

  const createSite = ({...props}) => {
    ReactDOM.render((
      <Router>
        <Site {...props} />
      </Router>
    ), div);
    return div.querySelector('section.Site')
  }

  it('renders a semantic header tag', () => {
    const rendered = createSite()
    expect(rendered).toBeTruthy()
    expect(rendered.tagName).toBe("SECTION")
  })

  it('contains a semantic main tag', () => {
    const rendered = createSite()
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
          <Site />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
    setTimeout(() => {
      ReactDOM.unmountComponentAtNode(div);
    })
  })
})
