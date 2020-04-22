import React, { Component } from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
import { Article } from 'common/js/contexts/article'
import { Sport } from 'common/js/contexts/sport'
import SportSelectField from 'common/js/forms/components/sport-select-field'
import MediaArticle from 'common/js/components/media-article'
import pixelTracker from 'common/js/helpers/pixel-tracker'

import './media.css'

let queue = 0

class MediaPage extends Component {
  state = { selected: {abbrGender: 'all'}, offset: 0 }
  sportSelectProps = {
    className: 'form-control',
    autoComplete: 'off',
    required: false,
  }

  async componentDidMount(){
    try {
      pixelTracker('track', 'PageView')
      const sportLoader = this.props.sportState.loaded ? Promise.resolve() : this.props.sportActions.getSports()
      const articleLoader = this.props.articleActions.getArticles()
      return await sportLoader.then(articleLoader)
    } catch (e) {
      console.error(e)
    }
  }

  onSportSelect = (e, v) => {
    queue = queue + 1
    if(!this.state.selected || (this.state.selected.abbr !== v.abbr)) this.getArticles(v.abbr, queue)
  }

  asyncSetState = (args) => new Promise((res) => this.setState(args, res))

  getArticles = async (selected, q) => {
    selected = this.props.sportActions.find(selected) || {abbrGender: 'all'}
    await this.asyncSetState({ selected, offset: 0 })
    if(queue === q) this.props.articleActions.getArticles(selected.abbrGender)
  }

  nextPage = () => {
    const articles = this.props.articleState[`${this.state.selected.abbrGender}`] || []

    if(this.state.offset + 3 < articles.length) this.setState({offset: this.state.offset + 3})
  }

  prevPage = () => {
    if(this.state.offset > 2) this.setState({offset: this.state.offset - 3})
  }

  render() {
    const { articleState = {}, sportState = {} } = this.props,
          { offset = 0 } = this.state,
          articles = articleState[`${this.state.selected.abbrGender}`] || [],
          renderButtons = (
            <div className="row">
              <div className="col-12">
                <div className='text-muted text-center py-5 d-flex justify-content-between'>
                  <button className='btn btn-secondary' onClick={this.prevPage} disabled={offset === 0}>
                    Prev
                  </button>
                  (click an article to view full size)
                  <button className='btn btn-secondary' onClick={this.nextPage} disabled={offset + 4 > articles.length}>
                    Next
                  </button>
                </div>
              </div>
            </div>
          )

    return (
      <div className='MediaPage py-5 bg-white row'>
        <div className="col">
          <div className="row">
            <div className='col'>
              <SportSelectField
                viewProps={this.sportSelectProps}
                onChange={this.onSportSelect}
                name='media_sport_select'
                value={this.state.selected.id}
                label='Select Sport'
              />
              <small>
                Select a sport to view articles only from that sport.
              </small>
            </div>
          </div>
          <hr/>
          <div className="row" ref={(tableRow)=>this.tableRow = tableRow}>
            <div className="col">
              <DisplayOrLoading display={(!!sportState.loaded) && (!!articleState.loaded)}>
                <div className='row'>
                  {
                    articles.length ? (
                      <div className="col-12 scroller-wrapper" >
                        {
                          renderButtons
                        }
                        <div className='scroller row'>
                          {articles.slice(offset, offset + 3).map((article, i) => (<MediaArticle {...article} key={`${offset}.${i}.${this.state.selected.abbrGender}`} />))}
                        </div>
                        {
                          renderButtons
                        }
                      </div>
                    ) : (
                      <div className="col-12" >
                        <p className='text-center text-muted'>
                          No articles to show, please try selecting a different sport.
                        </p>
                      </div>
                    )
                  }
                </div>
              </DisplayOrLoading>
            </div>
          </div>
        </div>
      </div>
    );
  }
}

export default Article.Decorator(Sport.Decorator(MediaPage))
