import React, { Component } from 'react';
import { LazyImage, Link } from 'react-component-templates/components'
import { staffBios } from './staff-bios'
import logo from 'common/assets/images/dus-logo.png'
// const staffBios = [
//   'TRfhbhNfgA8',
// ]

export default class OurStaffPage extends Component {
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
              Meet Our Staff!
            </h3>
          </header>
          <div className="row my-5">
            {
              staffBios.map(({Name, Bio, img}, key) => (
                <div key={key} className="col-xl-6 my-3">
                  <div className="card">
                    <div className="card-header">
                      <h5 className="text-center"><Name /></h5>
                    </div>
                    <div className="card-body">
                      <div className="row">
                        <div className="col-4">
                          <LazyImage src={img || logo} alt="Staff Bio Picture" placeholder={logo}/>
                        </div>
                        <div className="col"><Bio /></div>
                      </div>
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
