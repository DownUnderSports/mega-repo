import React from 'react';
import Component from 'common/js/components/component'
import { DisplayOrLoading, Link } from 'react-component-templates/components'

const fundraisingIdeasUrl = '/admin/fundraising_ideas.json'

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
    <tr key={id}>
      <td colSpan="2">
        <Link to={fundraisingIdeasUrl.replace('.json', `/${id}`)}>
          Edit { id }
        </Link>
      </td>
      <td colSpan="4">
        { title }
      </td>
      <td colSpan="5">
        { String(description || 'No Description Given').substring(0, 25) }{
          (String(description).length > 25)
            ? '...'
            : ''
        }
      </td>
      <td colSpan="1">
        { Number(image_count || 0) }
      </td>
      <td colSpan="1">
        { display_order ? Number(display_order) : 'Created At' }
      </td>
    </tr>

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
      <div className="FundraisingIdeas IndexPage">
        <h3 className="text-center mb-5">
          Fundraising Ideas
          <Link
            to="/admin/fundraising_ideas/new"
            className="btn btn-info float-right"
          >
            New Idea
          </Link>
        </h3>
        { this.renderErrors() }
        <DisplayOrLoading display={!this.state.loading}>
          <table className="table">
            <thead>
              <tr>
                <th colSpan="2">Link</th>
                <th colSpan="4">Title</th>
                <th colSpan="5">Description</th>
                <th colSpan="1">Image Count</th>
                <th colSpan="1">Order</th>
              </tr>
            </thead>
            <tbody>
              { ideas.map(this.showIdea) }
            </tbody>
          </table>
        </DisplayOrLoading>
      </div>
    );
  }
}
