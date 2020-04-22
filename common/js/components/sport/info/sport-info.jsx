import React, { Component } from 'react'
import { Sport } from 'common/js/contexts/sport'

import './sport-info.css';

export default class SportInfo extends Component {
  static propTypes = {
    sport: Sport.sportShape().isRequired,
  }
  render() {
    const { sport: { info: { tournament, firstYear, departingDates, teamCount, teamSize } } } = this.props

    return (
      <section className="sport-information card text-default">
        <header className='text-center card-header'>
          <h4>Info At A Glance</h4>
        </header>
        <div className="list-group">
          <div className="list-group-item" style={{borderRadius: 0}}>
            <div className="col-12 col-sm">
              <label htmlFor="competition_title" className="font-weight-bold">Competition:</label>
            </div>
            <div className="col">
              <span id="competition_title">{tournament}</span>
            </div>
          </div>
          <div className="list-group-item">
            <div className="col-12 col-sm">
              <label htmlFor="travel_date" className="font-weight-bold">Departing:</label>
            </div>
            <div className="col">
              <span id="travel_date">
                {
                  departingDates.split(' and ').map((txt, i) => (
                    <span key={i}>
                      {txt}
                    </span>
                  ))
                  .reduce((accu, elem) => {
                      return accu === null ? [elem] : [...accu, <div key={`${accu.length}.${Math.random()}`} style={{textAlign: 'center'}}>&amp;</div>, elem]
                  }, null)
                }
              </span>
            </div>
          </div>
          <div className="list-group-item">
            <div className="col-12 col-sm">
              <label htmlFor="started" className="font-weight-bold">First Started:</label>
            </div>
            <div className="col">
              <span id="started">{firstYear}</span>
            </div>
          </div>
          <div className="d-none list-group-item">
            <div className="col-12 col-sm">
              <label htmlFor="started" className="font-weight-bold">Team Size:</label>
            </div>
            <div className="col">
              <div className="row">
                <div className="col-12">
                  <strong>
                    <span id="team-count">{teamCount}</span>
                  </strong>
                </div>
              </div>
              <div className="row">
                <div className="col-12">
                  <i>
                    <span id="team-size">{teamSize}</span>
                  </i>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    )
  }
}
