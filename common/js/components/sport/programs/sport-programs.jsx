import React, { Component } from 'react'
import { string } from 'prop-types'
import { Sport } from 'common/js/contexts/sport'

export default class SportPrograms extends Component {
  static propTypes = {
    sport: Sport.sportShape().isRequired,
    sportName: string.isRequired
  }

  render() {
    const { sport: { full, info: { programs = [] } }, sportName = '' } = this.props;

    return (
      <section className="card text-default">
        <header className='text-center card-header'>
          <h4>Tournament Archives</h4>
        </header>
        <div className="list-group">
          {
            programs.map((year, i) => (<div key={i} className="list-group-item" style={{borderRadius: 0}}>
              <div className="col">
                <a
                  href={`/sports-programs/${sportName}/${year}/index.html`}
                  className="btn btn-block btn-info"
                  rel='noopener noreferrer'
                  target='_sports_program'>
                  {year} {full} Program
                </a>
              </div>
            </div>))
          }
        </div>
      </section>
    )
  }
}
