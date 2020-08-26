import React, { Component } from 'react'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import SimpleMDE from 'simplemde'
import 'simplemde/dist/simplemde.min.css'
import './travel-giveaways.css'

export default class TravelGiveawaysTermsPage extends Component {
  state = {
    loading: true,
    errors: null,
    body: '',
  }

  async componentDidMount() {
    await this.createEditor()
    this.setState({ loading: false })
  }

  componentDidUpdate(_, prevState) {
    if(this.editor && (prevState.body !== this.state.body)) this.editor.value(this.state.body)
  }

  createEditor = async () => {
    if(this.editor) return;

    if(this.refs.terms) {
      if(!this.state.body) await this.getValues()
      this.editor = new SimpleMDE({ element: this.refs.terms, initialValue: this.state.body })
    } else {
      return await new Promise(r => {
        setTimeout(() => this.createEditor().then(r), 100)
      })
    }
  }

  getValues = async () => {
    try {
      const result = await fetch('/admin/travel-giveaways.json'),
            { terms = {} } = await result.json(),
            { body } = terms || {}
      await (
        new Promise(
          r => this.setState({ body: String(body || ''), }, r)
        )
      )
    } catch(err) {
      console.error(err)

      await (new Promise(async r => {
        try {
          this.setState({errors: (await err.response.json()).errors, body: '' }, r)
        } catch(e) {
          this.setState({errors: [ err.toString() ], body: '' }, r)
        }
      }))
    }
  }

  submitChanges = async () => {
    try {
      await (new Promise(r => this.setState({ loading: true, errors: null }, r)))
      await fetch('/admin/travel-giveaways.json', {
        method: 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({
          terms: {
            ...this.state,
            body: this.editor.value()
          }
        })
      })

      await (new Promise(r => this.setState({ loading: false }, r)))
    } catch(err) {
      console.error(err)
      await (new Promise(async r => {
        try {
          this.setState({errors: (await err.response.json()).errors, loading: false }, r)
        } catch(e) {
          this.setState({errors: [ err.toString() ], loading: false }, r)
        }
      }))
    }
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

  render(){
    return <section className="Terms">
      <header className="form-group">
        <h3>
          Edit Travel Giveaway (Thank You Ticket) Rules
          <Link to="https://www.downundersports.com/travel-giveaways" className="btn btn-success float-right" target="_terms">View Live</Link>
        </h3>
        <div className="clearfix"></div>
      </header>
      <h5>
        Special Substitution Values:
      </h5>
      <table className="table table-bordered">
        <thead>
          <tr>
            <th>
              Value
            </th>
            <th>
              Description
            </th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>
              %YEAR%
            </td>
            <td>
              Program year for the shown terms
            </td>
          </tr>
        </tbody>
      </table>
      { this.renderErrors() }
      <div className="row form-group">
        <div className="col">
          <DisplayOrLoading
            display={!this.state.loading}
            message='LOADING...'
            loadingElement={
              <JellyBox className="authenticated-jelly-box" />
            }
          >
            <button onClick={this.submitChanges} className="btn btn-block btn-primary">
              Save Changes
            </button>
          </DisplayOrLoading>
        </div>
      </div>
      <div className="row form-group">
        <div className="col">
          <textarea ref="terms" name="terms[body]" id="terms[body]" className="form-control" rows="50"></textarea>
        </div>
      </div>
      <div className="row form-group">
        <div className="col">
          <DisplayOrLoading
            display={!this.state.loading}
            message='LOADING...'
            loadingElement={
              <JellyBox className="authenticated-jelly-box" />
            }
          >
            <button onClick={this.submitChanges} className="btn btn-block btn-primary">
              Save Changes
            </button>
          </DisplayOrLoading>
        </div>
      </div>
    </section>
  }
}
