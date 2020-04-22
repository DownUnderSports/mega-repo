import React from 'react'
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router } from 'react-router-dom';

import { CompanyInfo } from '../footer/components'

describe('Layouts::components - Footer::CompanyInfo', () => {
  const div = document.createElement('div');

  const createCompanyInfo = ({...props}) => {
    ReactDOM.render((
      <Router>
        <CompanyInfo {...props} />
      </Router>
    ), div);
    return div.querySelector('address')
  }

  it('renders a sematic address', () => {
    const rendered = createCompanyInfo()
    expect(rendered).toBeTruthy()
    expect(rendered.tagName).toBe("ADDRESS")
    ReactDOM.unmountComponentAtNode(div);
  })

  it('renders the company name', () => {
    const name = createCompanyInfo().querySelector('strong i')
    expect(name).toBeTruthy()
    expect(/down under sports/i.test(name.textContent)).toBeTruthy()
    ReactDOM.unmountComponentAtNode(div);
  })

  it('contains phone number, email, mailing address, and physical address', () => {
    const rendered = createCompanyInfo()

    const email = rendered.querySelector('a[data-content=email]'),
          phone = rendered.querySelector('a[data-content=phone]'),
          mailing = rendered.querySelector('a[data-content=mailing]'),
          physical = rendered.querySelector('a[data-content=physical]');

    expect(email).toBeTruthy()
    expect(/^mailto:/.test(email.href)).toBeTruthy()
    expect(email.tagName).toBe("A")

    expect(phone).toBeTruthy()
    expect(/^tel:/.test(phone.href)).toBeTruthy()
    expect(phone.tagName).toBe("A")

    expect(mailing).toBeTruthy()
    expect(/^PO Box/.test(mailing.innerHTML)).toBeTruthy()
    expect(mailing.tagName).toBe("A")

    expect(physical).toBeTruthy()
    expect(/^1755 N/.test(physical.innerHTML)).toBeTruthy()
    expect(physical.tagName).toBe("A")

    ReactDOM.unmountComponentAtNode(div);
  })

  it('is snapshotable', () => {
    const tree = renderer
      .create(
        <Router>
          <CompanyInfo />
        </Router>
      )
      .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
