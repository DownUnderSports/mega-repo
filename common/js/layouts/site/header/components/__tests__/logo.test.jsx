import React from 'react'
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import Logo from '../logo'

describe('common/js/components - Header::Logo', () => {
  const div = document.createElement('div');

  const createLogo = ({...props}) => {
    ReactDOM.render((
      <Router>
        <Logo {...props} />
      </Router>
    ), div);
    return div.querySelector('div.header-logo')
  }

  it('renders the header-logo', () => {
    const rendered = createLogo()
    expect(rendered).toBeTruthy()
    expect(rendered.tagName).toBe("DIV")
    expect(rendered.classList.contains('header-logo')).toBeTruthy()
    ReactDOM.unmountComponentAtNode(div);
  })

  it('contains a brand image', () => {
    const rendered = createLogo().querySelector('img')
    expect(rendered).toBeTruthy()
    expect(rendered.tagName).toBe("IMG")
    expect(rendered.alt).toBe('Site Logo')
    ReactDOM.unmountComponentAtNode(div);
  })

  it('logo is wrapped in a link home', () => {
    const base = createLogo(),
          img = base.querySelector('a > img'),
          linked = base.querySelector('a')
    expect(img).toBeTruthy()
    expect(linked.href).toMatch(/http:\/{2}[A-Za-z09\.]+\/?$/)
    ReactDOM.unmountComponentAtNode(div);
  })

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <Logo />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
