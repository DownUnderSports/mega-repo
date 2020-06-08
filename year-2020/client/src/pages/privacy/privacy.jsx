import React, { Component } from 'react'
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import SimpleMDE from 'simplemde'
import 'simplemde/dist/simplemde.min.css'
import './privacy.css'

export default class PrivacyPage extends Component {

  state = {
    loading: true,
    errors: null,
    body: ''
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

    if(this.refs.privacy) {
      if(!this.state.body) await this.getValues()
      this.editor = new SimpleMDE({ element: this.refs.privacy, initialValue: this.state.body })
    } else {
      return await new Promise(r => {
        setTimeout(() => this.createEditor().then(r), 100)
      })
    }
  }

  getValues = async () => {
    try {
      const result = await fetch('/admin/privacy_policy.json'),
            { privacy_policy = {} } = await result.json(),
            { body } = privacy_policy || {}
      await (
        new Promise(r => this.setState({ body: String(body || '') }, r))
      )
    } catch(err) {
      console.error(err)
      const errState = { body: '' }
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
      await fetch('/admin/privacy_policy.json', {
        method: 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({
          privacy_policy: {
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
    return <section className="Privacy">
      <header className="form-group">
        <h3>
          Edit Privacy Policy
          <Link to="https://www.downundersports.com/privacy" className="btn btn-success float-right" target="_privacy">View Live</Link>
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
      <div className="row form-group">
        <div className="col">
          <textarea ref="privacy" name="privacy_policy[body]" id="privacy_policy[body]" className="form-control" rows="50"></textarea>
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
