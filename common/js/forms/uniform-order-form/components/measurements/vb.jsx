import React, { PureComponent } from 'react'
import Instructions from './instructions'
import { volleyballJersey, volleyballShorts } from 'common/assets/images/sports/uniforms'

export default class VBMeasurements extends PureComponent {

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
                        <td>18</td>
                        <td>19</td>
                        <td>20.5</td>
                        <td>22.25</td>
                        <td>24.25</td>
                      </tr>
                      <tr>
                        <th>Body Length from HPS</th>
                        <td>26.75</td>
                        <td>27.5</td>
                        <td>28.25</td>
                        <td>29</td>
                        <td>29.75</td>
                      </tr>
                      <tr>
                        <th>Shoulder Width</th>
                        <td>14.25</td>
                        <td>15</td>
                        <td>15.75</td>
                        <td>16.5</td>
                        <td>17.25</td>
                      </tr>
                      <tr>
                        <th>Straight Arm Hole Depth</th>
                        <td>7.75</td>
                        <td>8.25</td>
                        <td>8.75</td>
                        <td>9.25</td>
                        <td>9.75</td>
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
                          <strong>
                            CF = Center Front
                          </strong>
                          <br/>
                          <strong>
                          HPS = High Point Shoulder
                          </strong>
                        </th>
                      </tr>
                    </tfoot>
                  </table>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={volleyballJersey} alt="volleyball jersey" className='img-fluid'/>
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
                        <th>Low Waist Relaxed</th>
                        <td>26</td>
                        <td>27</td>
                        <td>28.5</td>
                        <td>30.25</td>
                        <td>32.25</td>
                      </tr>
                      <tr>
                        <th>Hip - 6&quot; Down</th>
                        <td>30.5</td>
                        <td>33</td>
                        <td>35.5</td>
                        <td>38</td>
                        <td>40.5</td>
                      </tr>
                      <tr>
                        <th>Inseam</th>
                        <td>4</td>
                        <td>4</td>
                        <td>4</td>
                        <td>4</td>
                        <td>4</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={volleyballShorts} alt="volleyball shorts" className='img-fluid'/>
                </figure>
              </div>
            </div>
          </section>
        </div>
      </div>
    )
  }
}
