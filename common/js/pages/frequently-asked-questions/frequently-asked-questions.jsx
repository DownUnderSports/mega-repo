import React, { Component } from 'react';
import { Link } from 'react-component-templates/components';
import BasicVideo from 'common/js/components/basic-video'
import faqData from 'common/js/constants/faq-data'

export default class FrequentlyAskedQuestionsPage extends Component {
  componentWillUnmount() {
    this._urlParams = null
  }

  extractQueryOptions = () => {
    if(this._urlParams) return this._urlParams
    this._urlParams = {}
    const search = (window.location.search || '')
    console.log(search)
    search.replace(/^\?/, '').split('&').forEach(str => {
      if(str) {
        const split = str.split('=')
        console.log(str, split)
        if(this._urlParams[split[0]]) {
          console.log(this._urlParams[split[0]])
          if(!Array.isArray(this._urlParams[split[0]])) this._urlParams[split[0]] = [ this._urlParams[split[0]] ]
          this._urlParams[split[0]].push(split[1])
        } else {
          this._urlParams[split[0]] = split[1]
          console.log(this._urlParams[split[0]])
        }
      }
    })
    return this._urlParams
  }

  render() {
    this.extractQueryOptions()

    const dusId = (this._urlParams || {}).dus_id || ''
    return (
        <section className="mt-5 frequently-asked-questions-page">
          <header>
            <h3 className="text-center">
              Down Under Sports' Most Commonly Asked Questions
            </h3>
          </header>
          <div className="row my-5">
            <div className='col-12'>
              <Link className='btn btn-success btn-lg btn-block' to={`/deposit/${dusId}`}>How Do I Join the Team?</Link>
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
              <Link className='btn btn-success btn-lg btn-block' to={`/deposit/${dusId}`}>How Do I Join the Team?</Link>
            </div>
          </div>
        </section>
    );
  }
}
