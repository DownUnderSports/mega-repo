import React, { PureComponent } from 'react'
import Instructions from './instructions'
import {  trackAndCrossCountryMenJersey,
          trackAndCrossCountryMenShorts,
          trackAndCrossCountryWomenJersey,
          trackAndCrossCountryWomenShorts   } from 'common/assets/images/sports/uniforms'

export default class TFAndXCMeasurements extends PureComponent {
  // state = { showInstructions: false}

  // showInstructions = (ev) => {
  //   ev.preventDefault()
  //   ev.stopPropagation()
  //   this.setState({showInstructions: true})
  // }

  render() {
    const showWomen = !!this.props.showWomen

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
              {
                showWomen && (<div className='row' style={{marginTop: '2rem'}}>
                  <div className='col' style={{overflowX: 'auto'}}>
                    <table className='table table-bordered' style={{border: 'none'}}>
                      <thead>
                        <tr>
                          <th style={{border: 'none'}}>
                            <h3>Women&apos;s</h3>
                          </th>
                          <th>XS</th>
                          <th>S</th>
                          <th>M</th>
                          <th>L</th>
                          <th>XL</th>
                          <th>2XL</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <th>Bust</th>
                          <td>30-32</td>
                          <td>32-34</td>
                          <td>34-36</td>
                          <td>36-38</td>
                          <td>38-40</td>
                          <td>42-44</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <figure className='col-2 hidden-sm-down'>
                    <img src={trackAndCrossCountryWomenJersey} alt="women's track & cross country jersey" className='img-fluid'/>
                  </figure>
                </div>)
              }
              <div className='row' style={{marginTop: '2rem'}}>
                <div className='col' style={{overflowX: 'auto'}}>
                  <table className='table table-bordered' style={{border: 'none'}}>
                    <thead>
                      <tr>
                        <th style={{border: 'none'}}>
                          <h3><span className='hidden-female'>Men&apos;s/</span>Unisex</h3>
                        </th>
                        <th>XS</th>
                        <th>S</th>
                        <th>M</th>
                        <th>L</th>
                        <th>XL</th>
                        <th>2XL</th>
                        <th>3XL</th>
                        <th>4XL</th>
                        <th>5XL</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <th>Chest</th>
                        <td>32-34</td>
                        <td>34-36</td>
                        <td>38-40</td>
                        <td>42-44</td>
                        <td>46-48</td>
                        <td>50-52</td>
                        <td>54-56</td>
                        <td>58-60</td>
                        <td>62-64</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={trackAndCrossCountryMenJersey} alt="men's track & cross country jersey" className='img-fluid'/>
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
              {
                showWomen && (<div className='row' style={{marginTop: '2rem'}}>
                  <div className='col' style={{overflowX: 'auto'}}>
                    <table className='table table-bordered' style={{border: 'none'}}>
                      <thead>
                        <tr>
                          <th style={{border: 'none'}}>
                            <h3>Women&apos;s</h3>
                          </th>
                          <th>XS</th>
                          <th>S</th>
                          <th>M</th>
                          <th>L</th>
                          <th>XL</th>
                          <th>2XL</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <th>Waist</th>
                          <td>24-26</td>
                          <td>26-28</td>
                          <td>28-30</td>
                          <td>30-32</td>
                          <td>32-34</td>
                          <td>36-38</td>
                        </tr>
                        <tr>
                          <th>Hips</th>
                          <td>32-34</td>
                          <td>34-36</td>
                          <td>36-38</td>
                          <td>40-42</td>
                          <td>44-46</td>
                          <td>48-50</td>
                        </tr>
                        <tr>
                          <th>Inseam</th>
                          <td>28 cm</td>
                          <td>28 cm</td>
                          <td>29 cm</td>
                          <td>29 cm</td>
                          <td>30 cm</td>
                          <td>30 cm</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <figure className='col-2 hidden-sm-down'>
                    <img src={trackAndCrossCountryWomenShorts} alt="women's track & cross country shorts" className='img-fluid'/>
                  </figure>
                </div>)
              }
              <div className='row' style={{marginTop: '2rem'}}>
                <div className='col' style={{overflowX: 'auto'}}>
                  <table className='table table-bordered' style={{border: 'none'}}>
                    <thead>
                      <tr>
                        <th style={{border: 'none'}}>
                          <h3>
                            <span className='hidden-female'>Men&apos;s/</span>Unisex
                          </h3>
                        </th>
                        <th>XS</th>
                        <th>S</th>
                        <th>M</th>
                        <th>L</th>
                        <th>XL</th>
                        <th>2XL</th>
                        <th>3XL</th>
                        <th>4XL</th>
                        <th>5XL</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <th>Waist</th>
                        <td>26-28</td>
                        <td>28-30</td>
                        <td>32-34</td>
                        <td>36-38</td>
                        <td>40-42</td>
                        <td>44-46</td>
                        <td>48-50</td>
                        <td>52-54</td>
                        <td>56-58</td>
                      </tr>
                      <tr>
                        <th>Inseam</th>
                        <td>28 cm</td>
                        <td>29 cm</td>
                        <td>30 cm</td>
                        <td>31 cm</td>
                        <td>32 cm</td>
                        <td>33 cm</td>
                        <td>33 cm</td>
                        <td>34 cm</td>
                        <td>34 cm</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <figure className='col-2 hidden-sm-down'>
                  <img src={trackAndCrossCountryMenShorts} alt="men's track & cross country shorts" className='img-fluid'/>
                </figure>
              </div>
            </div>
          </section>
        </div>
      </div>
    )
  }
}
