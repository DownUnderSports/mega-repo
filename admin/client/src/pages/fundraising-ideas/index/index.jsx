import React from 'react';
import Component from 'common/js/components/component'
import { DisplayOrLoading, Link } from 'react-component-templates/components'

const fundraisingIdeasUrl = '/admin/fundraising_ideas'

export default class FundraisingIdeasIndexPage extends Component {
  state = { loading: true, ideas: [], errors: null }

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

  showIdea = ({ id, title, description, display_order, image_count }) =>
    <div className="row form-group">
      <div className="col-2">
        <Link to={`${fundraisingIdeasUrl}/${id}`}>
          Edit { id }
        </Link>
      </div>
      <div className="col-4">
        { title }
      </div>
      <div className="col-5">
        { String(description || 'No Description Given').substring(0, 25) }{
          (String(description).length > 25)
            ? '...'
            : ''
        }
      </div>
      <div className="col-1">
        { Number(image_count || 0) }
      </div>
    </div>

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
    const { ideas = [], errors } = this.state
    return (
      <div className="FundraisingIdeas IndexPage">
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
