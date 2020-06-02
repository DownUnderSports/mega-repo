import React, { Component } from 'react';
import { Link } from 'react-component-templates/components';
import BasicVideo from 'common/js/components/basic-video'
import faqData from 'common/js/constants/faq-data'

export default class FrequentlyAskedQuestionsPage extends Component {
  state = { dusId: '' }

  componentDidMount() {
    const params = this.extractQueryOptions()
    this.setState({ dusId: params.dus_id || params.dusId || '' })
  }

  extractQueryOptions = () => {
    const params = {}
    const search = (window.location.search || '')
    console.log(search)
    search.replace(/^\?/, '').split('&').forEach(str => {
      if(str) {
        const [ key, value ] = str.split('=')
        console.log(str, key, value)
        if(params[key]) {
          console.log(params[key])
          if(!Array.isArray(params[key])) params[key] = [ params[key] ]
          params[key].push(value)
        } else {
          params[key] = value
          console.log(params[key])
        }
      }
    })
    return params
  }

  render() {
    const { dusId = '' } = this.state
    return (
        <section className="mt-5 frequently-asked-questions-page">
          <header>
            <h3 className="text-center">
              Down Under Sports' Most Commonly Asked Questions
            </h3>
          </header>
          <div className="row my-5">
            <div className='col-12'>
              <div className="card">
                <div className="card-header">
                  <h5 className="text-center">How Do I Join the Team?</h5>
                </div>
                <div className="card-body p-0">
                  <Link
                    className='btn btn-success btn-lg btn-block rounded-0'
                    to={`/deposit/${dusId}`}
                  >
                    Click Here to Pay your Deposit!
                  </Link>
                </div>
              </div>
            </div>
            {
              faqData.map(({key, question}) => (
                <div key={key} className="col-md-6 my-3">
                  <div className="card">
                    <div className="card-header">
                      <h5 className="text-center">{question}</h5>
                    </div>
                    <div className="card-body p-0">
                      <BasicVideo url={`https://www.youtube.com/embed/${key}?rel=0&enablejsapi`} baseState="paused" displayClass="alt-background paused-background fullscreen-background rounded-bottom" />
                    </div>
                  </div>
                </div>
              ))
            }
            <div className='col-12'>
              <Link className='btn btn-success btn-lg btn-block' to={`/deposit/${dusId}`}>Join the Team!</Link>
            </div>
          </div>
        </section>
    );
  }
}
