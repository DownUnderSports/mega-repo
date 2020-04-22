import React, { PureComponent } from 'react'
import { footballJersey, footballShorts } from 'common/assets/images/sports/uniforms'

export default class FBMeasurements extends PureComponent {

  render() {
    return (
      <div className='row'>
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
                        <th>M</th>
                        <th>L</th>
                        <th>XL</th>
                        <th>2XL</th>
                        <th>3XL</th>
                        <th>4XL</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <th>Chest</th>
                        <td>48</td>
                        <td>52</td>
                        <td>52</td>
                        <td>56</td>
                        <td>60</td>
                        <td>64</td>
                      </tr>
                      <tr>
                        <th>Length</th>
                        <td>35</td>
                        <td>37</td>
                        <td>37</td>
                        <td>38</td>
                        <td>39</td>
                        <td>40</td>
                      </tr>
                      <tr>
                        <th>Sleeve Length</th>
                        <td>6.5</td>
                        <td>6.5</td>
                        <td>6.5</td>
                        <td>6.5</td>
                        <td>6.5</td>
                        <td>6.5</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={footballJersey} alt="football jersey" className='img-fluid'/>
                </figure>
                <div className="col-12 mb-3 text-center">
                  <i>
                    You will receive both a red and blue jersey
                  </i>
                </div>
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
                          <h3>Pants</h3>
                        </th>
                        <th>S</th>
                        <th>M</th>
                        <th>L</th>
                        <th>XL</th>
                        <th>2XL</th>
                        <th>3XL</th>
                        <th>4XL</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <th>Inseam</th>
                        <td>15.5</td>
                        <td>15.5</td>
                        <td>16</td>
                        <td>16</td>
                        <td>16</td>
                        <td>16.5</td>
                        <td>16.5</td>
                      </tr>
                      <tr>
                        <th>Waist Relaxed</th>
                        <td>27</td>
                        <td>29</td>
                        <td>32</td>
                        <td>35</td>
                        <td>38</td>
                        <td>42</td>
                        <td>46</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={footballShorts} alt="football pants" className='img-fluid'/>
                </figure>
              </div>
            </div>
          </section>
        </div>
      </div>
    )
  }
}
