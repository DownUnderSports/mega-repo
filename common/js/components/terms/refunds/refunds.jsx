import React, {Component} from 'react'
import { Link } from 'react-component-templates/components';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import marked from 'marked'
import './refunds.css'

export default class Refunds extends Component {
  state = { body: '', parsed: '' }

  async componentDidMount() {
    this.getTerms()
  }

  componentDidUpdate(_, prevState) {
    if(prevState.body !== this.state.body) this.setState({ parsed: marked(`1. ${String(this.state.body || 'An Error Occured, Please Contact Our Office').trim()}`) })
  }

  getTerms = async () => {
    try {
      const result = await fetch('/api/terms.json'),
            { terms = {} } = await result.json(),
            { body: raw } = terms || {},
            body = /<!-- BEGIN REFUNDS -->([\S\s]+)<!-- END REFUNDS -->/.exec(String(raw || ''))[1]
      await (
        new Promise(
          r => this.setState({ body }, r)
        )
      )
    } catch(err) {
      console.error(err)
      await (new Promise(r => this.setState({ body: 'An Error Occured, Please Contact Our Office' })))
    }
  }

  render(){
    const { className = '', headerProps = {}, termProps = {}, ...props} = this.props
    return (
      <>
        <section key="refunds-section" className={`refunds-section ${className}`} {...props}>
          <header className='form-group' {...headerProps}>
            <h3 className='text-center'>
              International Sports Specialists, Inc. <br/>
              D.B.A. Down Under Sports (&ldquo;DUS&rdquo;) <br/>
              <br/>
              DUS Refund Policy <br/>
            </h3>
          </header>
          <DisplayOrLoading
            display={!!this.state.parsed}
            message='LOADING...'
            loadingElement={
              <JellyBox className="authenticated-jelly-box" />
            }
          >
            <div className="Terms" {...termProps} dangerouslySetInnerHTML={{ __html: this.state.parsed }} />
          </DisplayOrLoading>
        </section>
        <Link key="full-link" to='/terms' className='float-right d-print-none'>
          Click Here to view the full Down Under Sports Terms &amp; Conditions
        </Link>
        <div className='clearfix'></div>
      </>

    )
  }
}
