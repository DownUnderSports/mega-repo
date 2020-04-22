import React, {Component} from 'react'
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import marked from 'marked'

export default class Privacy extends Component {
  state = { body: '', parsed: '' }

  async componentDidMount() {
    this.getPrivacy()
  }

  componentDidUpdate(_, prevState) {
    if(prevState.body !== this.state.body) this.setState({ parsed: this.markdown })
  }

  get markdown() {
    return marked(this.state.body || 'An Error Occured, Please Contact Our Office')
           .replace(/<h([1-6])\s+id=['"][a-z-]+-a-[a-z-]+['"]>/, "<h$1>")
  }

  getPrivacy = async () => {
    try {
      const result = await fetch('/api/privacy_policies.json'),
            { privacy_policy = {} } = await result.json(),
            { body: raw } = privacy_policy || {},
            body = String(raw || 'An Error Occured, Please Contact Our Office')
      await (
        new Promise(
          r => this.setState({ body }, r)
        )
      )
    } catch(err) {
      console.error(err)
      await (new Promise(r => this.setState({ body: '' })))
    }
  }

  render(){
    const { className = '', headerProps = {}, privacyProps = {}, ...props } = this.props
    return (
      <section className={`privacy-section ${className}`} {...props}>
        <header className='form-group' {...headerProps}>
          <h3 className='text-center'>
            International Sports Specialists, Inc. <br/>
            D.B.A. Down Under Sports (&ldquo;DUS&rdquo;) <br/>
            <br/>
            {/* eslint-disable-next-line */}
            Privacy Policy<a id="privacy-policy" /><br/>
          </h3>
        </header>
        <DisplayOrLoading
          display={!!this.state.parsed}
          message='LOADING...'
          loadingElement={
            <JellyBox className="page-loader" />
          }
        >
          <div className="Privacy" {...privacyProps} dangerouslySetInnerHTML={{ __html: this.state.parsed }} />
        </DisplayOrLoading>
      </section>
    )
  }
}
