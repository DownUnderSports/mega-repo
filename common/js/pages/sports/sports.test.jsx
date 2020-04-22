import React from 'react';
import ReactDOM from 'react-dom';
import renderer from 'react-test-renderer';
import { MemoryRouter as Router, Route } from 'react-router-dom';

import SportsPage from './sports';

describe('Pages - SportsPage', () => {
  const div = document.createElement('div');

  const createSportsPage = ({...props}) => {
    ReactDOM.render((
      <Router>
        <Route component={(routeProps) => <SportsPage {...props} {...routeProps} path="/sports" />}/>
      </Router>
    ), div);
    return div.querySelector('section')
  }

  describe('Index', () => {
    it('renders by default')
    it('has a sport lookup form')

    it('is snapshotable', () => {
      const tree = renderer
        .create(
          <Router initialEntries={['/sports']}>
            <Route component={SportsPage} path="/sports" />
          </Router>
        )
        .toJSON();
      expect(tree).toMatchSnapshot()
    })
  })

  describe('Show', () => {
    it('pulls up data on a sport')
    it('data can be edited by double clicking')

    it('is snapshotable', () => {
      const tree = renderer
        .create(
          <Router initialEntries={['/sports/1']}>
            <Route component={SportsPage} path="/sports" />
          </Router>
        )
        .toJSON();
      expect(tree).toMatchSnapshot()
    })
  })

  describe('New', () => {
    it('renders the sport input form')

    it('is snapshotable', () => {
      const tree = renderer
        .create(
          <Router initialEntries={['/sports/new']}>
            <Route component={SportsPage} path="/sports" />
          </Router>
        )
        .toJSON();
      expect(tree).toMatchSnapshot()
    })
  })
})
