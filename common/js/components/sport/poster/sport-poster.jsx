import React, { Component } from 'react'
import { string } from 'prop-types'
import { LazyImage } from 'react-component-templates/components'

import posterImages from 'common/assets/images/sports/posters'

export default class SportPoster extends Component {
  static propTypes = {
    sportName: string.isRequired
  }

  render() {
    const { sportName } = this.props

    return (
      <a href={posterImages[sportName]} rel='noopener noreferrer' target='_sports_program'>
        <LazyImage
          className='img-fluid'
          src={posterImages[sportName]}
          alt={sportName}
          title={sportName}
          useLoader
          loaderProps={{loaderStyles: {width: '100px', height: '100px'}}}
        />
      </a>
    )
  }
}
