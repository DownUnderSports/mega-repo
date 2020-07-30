import React from 'react';
import Component from 'common/js/components/component'
import { DisplayOrLoading } from 'react-component-templates/components'
import marked from 'marked'
import './fundraising-ideas.css'

const fundraisingIdeasUrl = '/api/fundraising_ideas'

export default class FundraisingIdeasPage extends Component {
  state = { loading: true, ideas: [], errors: null, selectedImg: null, selectedImgClass: '' }

  componentDidMount() {
    Component.prototype.componentDidMount.call(this)
    this.loadIdeas()
  }

  loadIdeas = async () => {
    try {
      this.setState({ loading: true })
      this._fetchingResource = fetch(fundraisingIdeasUrl, { timeout: 5000 })
      const result = await this._fetchingResource,
            { fundraising_ideas: ideas = [] } = await result.json()

      for (let i = 0; i < ideas.length; i++) {
        const idea = ideas[i]
        if(idea.description) idea.parsed = marked(idea.description)
      }

      await this.setStateAsync({ ideas, loading: false })
    } catch(err) {
      if(this._isMounted) await this.handleError(err)
    }
  }

  handleError = async (err) => {
    try {
      const errorResponse = await err.response.json()
      console.error(errorResponse)

      return await this.setStateAsync({
        errors: errorResponse.errors || [ errorResponse.message ],
        loading: false
      })
    } catch(e) {
      console.error(err)
      return await this.setStateAsync({errors: [ err.message ], loading: false})
    }
  }

  showIdea = ({ id, title, parsed, display_order, images = [] }) =>
    <div key={id || 'new'} className="row form-group">
      <div className="col-12">
        <div className="card">
          <div className="card-header text-center">
            <h5 className="card-title">{title}</h5>
          </div>
          <div className="card-body">
            {
              !!parsed && (
                <div
                  className="card-text"
                  dangerouslySetInnerHTML={{ __html: parsed }}
                />
              )
            }
            {
              !!parsed
              && !!images.length
              && (
                <div className="row">
                  <div className="col-12"><hr/></div>
                  { images.map((img) => this.showImage(img, images.size)) }
                </div>
              )
            }
          </div>
        </div>
      </div>
    </div>

  toggleImageClass = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    const id = ev.currentTarget.dataset.id
    try {
      if(!id || (id === this.state.selectedImg)) {
        this.setState({ selectedImg: null, selectedImgClass: 'grow' }, () => {
          setTimeout(() => {
            this.setState({ selectedImgClass: '' })
          }, 100)
        })
      } else {
        this.setState({ selectedImg: id, selectedImgClass: 'grow' }, () => {
          setTimeout(() => {
            this.setState({ selectedImgClass: 'grow grown' })
          })
        })
      }
    } catch (e) {
      console.error(e)
      this.setState({ selectedImg: '' })
    }
  }

  showImage = ({ id, alt, src, full_size }, imgCount) => {
    if(!src) return false

    const isImg = this.state.selectedImg
                    && (String(this.state.selectedImg) === String(id)),
          imgClass = isImg ? this.state.selectedImgClass : '',
          size = imgCount > 2 ? '-4' : ''

    return (
      <div
        key={id}
        className={`col${size} form-group idea-img ${imgClass}`}
      >
        <div
          className="img-wrapper"
          onClick={this.toggleImageClass}
          data-tooltip={'click to view full size'}
          data-id={id}
        >
          <img
            className={`img-fluid ${isImg ? 'centered' : 'clickable'} rounded`}
            src={isImg ? (full_size || src) : src}
            alt={alt}
          />
          <button
            type="button"
            className="close rounded-circle tooltip-nowrap"
            aria-label="Close"
            data-tooltip="Close Fullscreen View"
          >
            <span aria-hidden="true">&times;</span>
          </button>
          {this.state.image && <i className="material-icons search rounded clickable">search</i>}
        </div>
      </div>
    )
  }

  renderErrors = () =>
    !!this.state.errors && (
      <div className="alert alert-danger form-group" role="alert">
        {
          this.state.errors.map((v, k) => (
            <div className='row' key={k}>
              <div className="col">
                { v }
              </div>
            </div>
          ))
        }
      </div>
    )

  render() {
    const { ideas = [] } = this.state
    return (
      <div className="fundraising-idea-page">
        <h3 className="text-center">
          Fundraising Ideas
        </h3>
        <hr/>
        { this.renderErrors() }
        <DisplayOrLoading display={!this.state.loading}>
          {
            ideas.map(this.showIdea)
          }
        </DisplayOrLoading>
      </div>
    );
  }
}
