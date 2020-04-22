import React from 'react'
import Component from 'common/js/components/component/async'

export default class MeetingCountdown extends Component {
  constructor(props) {
    super(props)
    this.state = {
      time: new Date(props.time || null).getTime(),
      interval: null,
      distance: 0,
      days: 0,
      hours: 0,
      minutes: 0,
      seconds: 0,
    }
  }

  afterMount = async () => {
    await this.beforeUnmount()
    if(this._isMounted) {
      const interval = setInterval(this.loop, 1000)
      await this.setStateAsync({ interval })
    }
    return true
  }

  beforeUnmount = async () => {
    if(this.state.interval) clearInterval(this.state.interval)
    return true
  }

  loop = () => {
    const now = new Date().getTime(),
          multiplier = this.state.time < now ? -1 : 1,
          distance = Math.abs(this.state.time - now),
          days = Math.floor(distance / (1000 * 60 * 60 * 24)) * multiplier,
          hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)) * multiplier,
          minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60)) * multiplier,
          seconds = Math.floor((distance % (1000 * 60)) / 1000) * multiplier
    this.setState({ distance, days, hours, minutes, seconds })
  }

  renderSection(k) {
    const v = this.state[k]
    return (
      <li className='mx-2 text-center'>
        <span className='d-block'>
          {v}
        </span>
        <span>
          {k.toUpperCase()}
        </span>
      </li>
    )
  }

  render() {
    return (
      <ul className="countdown-timer d-flex justify-content-center">
        {this.renderSection('days')}
        {this.renderSection('hours')}
        {this.renderSection('minutes')}
        {this.renderSection('seconds')}
      </ul>
    )
  }
}
