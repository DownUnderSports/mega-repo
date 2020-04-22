import React, { PureComponent } from 'react'
import Instructions from './instructions'
import { basketballJersey, basketballShorts } from 'common/assets/images/sports/uniforms'

export default class BBBAndGBBMeasurements extends PureComponent {

  render() {
    return (
      <div className='row'>
        <div className="col-12 mb-3">
          <Instructions />
        </div>
        <div className="col-12">
          <section className="card">
            <header className="card-header p-3">
              <h3>Jersey</h3>
            </header>
            <div className="container-fluid">
              <div className='row' style={{marginTop: '2rem'}}>
                <div className='col' style={{overflowX: 'auto'}}>
                  <table className='table table-bordered' style={{border: 'none'}}>
                    <thead>
                      <tr>
                        <th style={{border: 'none'}}>
                          <h3>Jersey</h3>
                        </th>
                        <th>S</th>
                        <th>M</th>
                        <th>L</th>
                        <th>XL</th>
                        <th>2XL</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <th>1/2 chest 1&quot; below armhole</th>
                        <td>18.75</td>
                        <td>20.75</td>
                        <td>22.75</td>
                        <td>24.75</td>
                        <td>26.75</td>
                      </tr>
                      <tr>
                        <th>Body Length from HPS</th>
                        <td>30.25</td>
                        <td>31.375</td>
                        <td>32.5</td>
                        <td>33.5</td>
                        <td>34</td>
                      </tr>
                      <tr>
                        <th>Front neck drop (seam to seam)</th>
                        <td>5.5</td>
                        <td>5.75</td>
                        <td>6</td>
                        <td>6.25</td>
                        <td>6.5</td>
                      </tr>
                      <tr>
                        <th>1/2 Armhole Curve</th>
                        <td>9.375</td>
                        <td>10.125</td>
                        <td>11</td>
                        <td>11.75</td>
                        <td>12.5</td>
                      </tr>
                      <tr>
                        <th>CF Panel Width @ Chest</th>
                        <td>10.75</td>
                        <td>11.25</td>
                        <td>12.375</td>
                        <td>13.5</td>
                        <td>14.625</td>
                      </tr>
                    </tbody>
                    <tfoot>
                      <tr>
                        <th colSpan="8" className='text-right' style={{border: 'none'}}>
                          CF = Center Front
                          <br/>
                          HPS = High Point of Shoulder
                        </th>
                      </tr>
                    </tfoot>
                  </table>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={basketballJersey} alt="basketball jersey" className='img-fluid'/>
                </figure>
              </div>
            </div>
          </section>
        </div>
        <div className="col-12" style={{marginTop: '2rem'}}>
          <section className="card">
            <header className="card-header">
              <h3>Shorts</h3>
            </header>
            <div className="card-body">
              <div className='row' style={{marginTop: '2rem'}}>
                <div className='col' style={{overflowX: 'auto'}}>
                  <table className='table table-bordered' style={{border: 'none'}}>
                    <thead>
                      <tr>
                        <th style={{border: 'none'}}>
                          <h3>Shorts</h3>
                        </th>
                        <th>S</th>
                        <th>M</th>
                        <th>L</th>
                        <th>XL</th>
                        <th>2XL</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <th>Waist Relaxed</th>
                        <td>12.5</td>
                        <td>13.75</td>
                        <td>15</td>
                        <td>16.25</td>
                        <td>17.5</td>
                      </tr>
                      <tr>
                        <th>Waist Stretched</th>
                        <td>19.5</td>
                        <td>21.5</td>
                        <td>23.5</td>
                        <td>25.5</td>
                        <td>27.5</td>
                      </tr>
                      <tr>
                        <th>Inseam</th>
                        <td>8.5</td>
                        <td>8.75</td>
                        <td>9</td>
                        <td>9.25</td>
                        <td>9.25</td>
                      </tr>
                      <tr>
                        <th>Waistband Elastic Height</th>
                        <td>2</td>
                        <td>2</td>
                        <td>2</td>
                        <td>2</td>
                        <td>2</td>
                      </tr>
                    </tbody>
                  </table>
                  <span className="float-right"><strong>Measurements are from Hip to Hip</strong></span>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={basketballShorts} alt="basketball shorts" className='img-fluid'/>
                </figure>
                <div className="col-12 mb-3 text-center">
                  <hr/>
                  <i>
                    Shorts and Jerseys are reversible
                  </i>
                </div>
              </div>
            </div>
          </section>
        </div>
      </div>
    )
  }
}
