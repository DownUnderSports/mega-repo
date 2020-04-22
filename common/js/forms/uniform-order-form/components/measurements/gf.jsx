import React, { PureComponent } from 'react'
import Instructions from './gf-instructions'
import { golfPolo } from 'common/assets/images/sports/uniforms'

export default class GFMeasurements extends PureComponent {

  render() {
    return (
      <div className='row'>
        <div className="col-12 mb-3">
          <Instructions />
        </div>
        <div className="col-12">
          <section className="card">
            <header className="card-header p-3">
              <h3>Polo</h3>
            </header>
            <div className="container-fluid">
              <div className='row' style={{marginTop: '2rem'}}>
                <div className='col' style={{overflowX: 'auto'}}>
                  <table className='table table-bordered' style={{border: 'none'}}>
                    <thead>
                      <tr>
                        <th style={{border: 'none'}}>
                          <h3>Polo</h3>
                        </th>
                        <th>XS</th>
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
                        <td>Chest</td>
                        <td>18.5</td>
                        <td>20</td>
                        <td>21.5</td>
                        <td>23</td>
                        <td>24.5</td>
                        <td>26</td>
                        <td>28</td>
                        <td>30</td>
                      </tr>
                      <tr>
                        <td>Sleeve Length</td>
                        <td>17.75</td>
                        <td>18.5</td>
                        <td>19.25</td>
                        <td>20</td>
                        <td>20.75</td>
                        <td>21.5</td>
                        <td>22.25</td>
                        <td>23</td>
                      </tr>
                      <tr>
                      <td>Body Length at Back</td>
                      <td>28</td>
                        <td>29</td>
                        <td>30</td>
                        <td>31</td>
                        <td>32</td>
                        <td>33</td>
                        <td>33.5</td>
                        <td>34</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={golfPolo} alt="golf polo" className='img-fluid'/>
                </figure>
                <div className="col-12 mb-3 text-center">
                  <i>
                    You will receive both a red and blue polo
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
