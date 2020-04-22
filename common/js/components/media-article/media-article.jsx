import React, { Component } from 'react'
import { string, number } from 'prop-types'

export default class MediaArticle extends Component {
  static propTypes = {
    url: string.isRequired,
    thumb: string.isRequired,
    large: string.isRequired,
    header: string,
    sport_id: number,
    sport_abbr_gender: string
  }

  constructor(props){
    super(props)
    this.state = {
      show: props.thumb
    }
  }

  showLarge = () => this.setState({show: this.props.large})
  showThumb = () => this.setState({show: this.props.thumb})

  render() {
    const { url, header, sport_abbr_gender } = this.props

    return (
      <span className='image-wrapper' data-sport={sport_abbr_gender}>
        <a href={url} target='_media_article' rel='noopener noreferrer'>
          {header && <h4 className='text-center'>{header}</h4>}
          <img
            src={this.state.show}
            alt={header}
            onMouseEnter={this.showLarge}
            onMouseLeave={this.showThumb}
          />
        </a>
      </span>
    )
  }
}
