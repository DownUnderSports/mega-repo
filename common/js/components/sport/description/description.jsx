import React, { Component } from 'react'
import { Sport } from 'common/js/contexts/sport'

import './description.css'

export default class SportDescription extends Component {
  static propTypes = {
    sport: Sport.sportShape().isRequired,
  }

  render() {
    const { sport: { fullGender, info: { description = '' } } } = this.props

    return (
      <section className="sport-description card text-default">
        <header className='text-center card-header'>
          <h4>About {fullGender}</h4>
        </header>
        <div className="main card-body">
          {description.split("\n").map((line, i) => <p key={i}>{line}</p>)}
        </div>
      </section>
    )
  }
}
