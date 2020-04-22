import React, { Component } from 'react';
import pixelTracker from 'common/js/helpers/pixel-tracker'

export default class SportsIndexPage extends Component {
  componentDidMount() {
    pixelTracker('track', 'PageView')
    const el = window.document.getElementById('sport-page-nav-trigger')
    el && (el.checked = true)
  }

  render() {
    return (
      <section className='row'>
        <header className="col-12 form-group">
          <h3>
            <i>
              Select a Sport from the menu above to view more details
            </i>
          </h3>
        </header>
        <div className="col-12 form-group">
          <p>
          </p>
        </div>
      </section>
    )
  }
}
