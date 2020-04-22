import React, { Component } from 'react'
import { Sport } from 'common/js/contexts/sport'

import './bullet-points.css'

export default class SportBulletPoints extends Component {
  static propTypes = {
    sport: Sport.sportShape().isRequired,
  }

  render() {
    const { sport: { info: { bulletPoints = [] } } } = this.props

    return (
      <section className="sport-bullet-points card text-default">
        <header className='text-center card-header'>
          <h4>Practice &amp; Competition</h4>
        </header>
        <div className="main list-group">
          {
            bulletPoints.map((point, i) => (
              <div key={i} className="list-group-item" style={{borderRadius: 0}}>
                <div className="col bullet-point">
                  <strong>
                    &bull;&nbsp;{point}
                  </strong>
                </div>
              </div>
            ))
          }
        </div>
      </section>
    )
  }
}
