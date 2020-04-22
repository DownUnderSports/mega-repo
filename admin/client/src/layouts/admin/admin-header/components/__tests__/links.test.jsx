import React from 'react'
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import { HeaderLinks } from '../'

describe('common/js/components - Header::Links', () => {
  const div = document.createElement('div');

  const createLinks = (props) => {
    ReactDOM.render((
      <Router>
        <HeaderLinks {...props} />
      </Router>
    ), div);
    return div.querySelector('ul')
  }

  it('renders the header-menu', () => {
    const rendered = createLinks({
      links: []
    })
    expect(rendered).toBeTruthy()
    expect(rendered.tagName).toBe("UL")
    expect(rendered.classList.contains('navbar-nav')).toBeTruthy()
  })

  it('requires a list of links', () => {
    const con = global.console
    global.console = {error: jest.fn()}
    createLinks()
    expect(console.error).toBeCalled()
    ReactDOM.unmountComponentAtNode(div);
    global.console = con
  })

  it('contains a menu wrapper with a list of links', () => {
    let links = createLinks({
          links: []
        }).querySelectorAll('a')

    expect(links.length).toBe(0)
    ReactDOM.unmountComponentAtNode(div)

    links = createLinks({
      links: [
        {to: '/', children: 'test'},
        {to: '/', children: 'test'},
        {to: '/', children: 'test'},
        {to: '/', children: 'test'},
        {to: '/', children: 'test'},
      ]
    }).querySelectorAll('a')
    expect(links.length).toBe(5)
  })

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <HeaderLinks
            links={[
              {
                to: '/test',
                children: 'TEST'
              },
              {
                to: '/test/2',
                children: 'TEST 2'
              },
              {
                to: '/test/3',
                children: (
                  <div>
                    <h1>
                      TEST 3
                    </h1>
                  </div>
                )
              },
            ]}
          />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
    setTimeout(() => {
      ReactDOM.unmountComponentAtNode(div);
    })
  })
})
