import React, { PureComponent } from 'react'
import pixelTracker from 'common/js/helpers/pixel-tracker'
import RefundTerms from 'common/js/components/terms/refunds'
import './refunds.css'

export default class RefundsPage extends PureComponent {
  componentDidMount() {
    pixelTracker('track', 'PageView')
  }

  render() {
    return (
      <RefundTerms
        className='my-5 bg-light border rounded p-3'
      />
    )
  }
}
