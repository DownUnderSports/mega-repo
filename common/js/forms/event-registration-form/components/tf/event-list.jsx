import React, { Component } from 'react'

import AntiLink from 'common/js/components/anti-link'

import events from 'common/assets/json/events'

export default class EventList extends Component {
  constructor(props) {
    super(props)
    this.state = {
      running: false,
      jumping: false,
      throwing: false
    }
  }
  render() {
    return (<section>
      <header className='form-group'>
        <h1 className='text-center'>
          Available Events
        </h1>
        <h5 className='text-center'>
          Athlete&apos;s <u>are</u> allowed to compete in <u>older</u> age groups but <i><u>cannot</u> compete in younger events.</i>
        </h5>
      </header>

      {
        Object.keys(events).map((key, i) => (<div className='row form-group' key={i}>
          <div className="col">
            <h3 className="text-center">
              <AntiLink label={`Open ${key.titleize()} Events`} onClick={() => {
                let val = {}
                val[key] = !this.state[key]
                this.setState(val)
              }}>{key.titleize()} Events</AntiLink>
            </h3>
            {
              this.state[key] && events[key].map((ev, idx) => (<div key={`${i}.${idx}`} className="row form-group">
                <div className="col">
                  <h4 className='text-center form-group'>
                    {ev.event}
                  </h4>
                  {
                    ev.competency && (
                      <p className='text-center text-danger'>
                        <strong>
                          <u>
                            Competing in { ev.event } requires a signed certificate of competency by your coach.
                          </u>
                        </strong>
                      </p>
                    )
                  }
                  <div className="row form-group">
                    {
                      ['M', 'F'].map((gender, gdx)=> (<div key={`${i}.${idx}.${gdx}`} className='col'>
                        <h6>
                          {gender === 'F' ? 'Wom' : 'M'}en&apos;s Ages
                        </h6>
                        <ul className='list-group'>
                          {
                            ev.all ? (<li className='list-group-item'>
                              All Age Groups
                            </li>) : (ev[gender].length ? ev[gender].map((group, adx) => (<li className='list-group-item' key={`${i}.${idx}.${gdx}.${adx}`}>
                              {group[0]}{group[1] ? `/${group[1]} Years` : ' Years & Older'}
                            </li>)) : (<li className='list-group-item'>
                              None
                            </li>))
                          }

                        </ul>
                      </div>))
                    }
                  </div>
                  <hr/>
                </div>
              </div>))
            }
            <hr/>
            <hr/>
          </div>
        </div>))
      }
    </section>)
  }
}
