import React, { Component } from 'react'
import { TextField } from 'react-component-templates/form-components';
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import SimpleMDE from 'simplemde'
import 'simplemde/dist/simplemde.min.css'
import './terms.css'

export default class TermsPage extends Component {

  state = {
    loading: true,
    errors: null,
    body: '',
    adult_signed_terms_link: '',
    minor_signed_terms_link: ''
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
      const result = await fetch('/admin/terms.json'),
            { terms = {} } = await result.json(),
            { body, adult_signed_terms_link, minor_signed_terms_link } = terms || {}
      await (
        new Promise(
          r => this.setState({
            body: String(body || ''),
            adult_signed_terms_link: String(adult_signed_terms_link || ''),
            minor_signed_terms_link: String(minor_signed_terms_link || '')
          }, r)
        )
      )
    } catch(err) {
      console.error(err)
      const errState = { body: '', adult_signed_terms_link: '', minor_signed_terms_link: '' }
      await (new Promise(async r => {
        try {
          this.setState({errors: (await err.response.json()).errors, ...errState}, r)
        } catch(e) {
          this.setState({errors: [ err.toString() ], ...errState}, r)
        }
      }))
    }
  }

  submitChanges = async () => {
    try {
      await (new Promise(r => this.setState({ loading: true, errors: null }, r)))
      await fetch('/admin/terms.json', {
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

  onMinorLinkChange = (ev) => this.setState({ minor_signed_terms_link: ev.currentTarget.value })
  onAdultLinkChange = (ev) => this.setState({ adult_signed_terms_link: ev.currentTarget.value })

  signedLinks = () => <div className="row">
    <div className="col-md form-group">
      <TextField
        ref="minor"
        name="terms[minor_signed_terms_link]"
        value={this.state.minor_signed_terms_link || ''}
        onChange={this.onMinorLinkChange}
        className="form-control"
        label="Minor Signed Terms Link"
        required
      />
    </div>
    <div className="col-md form-group">
      <TextField
        ref="adult"
        name="terms[adult_signed_terms_link]"
        value={this.state.adult_signed_terms_link || ''}
        onChange={this.onAdultLinkChange}
        className="form-control"
        label="Adult Signed Terms Link"
        required
      />
    </div>
    <div className="col-12 form-group text-right">
      <a target="_blank" rel="noopener noreferrer" href="https://www.markdowntutorial.com/">Learn Markdown</a>
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

  render(){
    return <section className="Terms">
      <header className="form-group">
        <h3>
          Edit Website Terms and Conditions
          <Link to="https://www.downundersports.com/terms" className="btn btn-success float-right" target="_terms">View Live</Link>
        </h3>
        <div className="clearfix"></div>
      </header>
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
      { this.signedLinks() }
      <div className="row form-group">
        <div className="col">
          <textarea ref="terms" name="terms[body]" id="terms[body]" className="form-control" rows="50"></textarea>
        </div>
      </div>
      { this.signedLinks() }
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
