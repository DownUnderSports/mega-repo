import React, {Component} from 'react'
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import marked from 'marked'

export default class ThankYouTicketTerms extends Component {
  state = { body: '', parsed: '' }

  async componentDidMount() {
    this.getTerms()
  }

  componentDidUpdate(_, prevState) {
    if(prevState.body !== this.state.body) this.setState({ parsed: marked(this.state.body || 'An Error Occured, Please Contact Our Office') })
  }

  getTerms = async () => {
    try {
      const result = await fetch('/api/thank-you-tickets.json'),
            { terms = {} } = await result.json(),
            { body: raw } = terms || {},
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
    const { className = '', headerProps = {}, termProps = {}, ...props} = this.props
    return (
      <section className={`terms-section ${className}`} {...props}>
        <header className='form-group' {...headerProps}>
          <h3 className='text-center'>
            Official Rules: Down Under Sports Thank You Tickets <br/>
            - No Purchase Necessary -
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
    )
  }
}
