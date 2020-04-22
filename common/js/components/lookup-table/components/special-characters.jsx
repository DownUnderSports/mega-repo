import React, { PureComponent } from 'react'

export default class SpecialCharacters extends PureComponent {
  state = { display: false }

  toggle = () => this.setState({ display: !this.state.display })

  render() {
    const { display } = this.state
    return (
      <div className="border-top mb-2">
        <div className="row">
          <div className="col-12">
            <div className="p-2 border-bottom clickable" onClick={this.toggle}>
              <h5 className='d-inline'>
                Special Characters:
              </h5>
              <div className="float-right">
                <i
                  className="material-icons"
                >
                  {display ? 'expand_less' : 'expand_more'}
                </i>
              </div>
            </div>
          </div>
          <div className={`col-12 ${display || 'd-none'}`}>
            <div className="p-2 border-bottom">
              <table className="table m-0">
                <tbody>
                  <tr>
                    <td className="border-top-0">
                      {'%'}
                    </td>
                    <td className="border-top-0">
                      Wildcard
                    </td>
                    <td className="border-top-0">
                      (Any Position)
                    </td>
                    <td className="border-top-0">
                      {'UT %BB'}
                    </td>
                  </tr>
                  <tr>
                    <td className="border-top-0">
                      {'='}
                    </td>
                    <td className="border-top-0">
                      Exact Match
                    </td>
                    <td className="border-top-0">
                      (Start Only)
                    </td>
                    <td className="border-top-0">
                      {'=Last'}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {'>'}
                    </td>
                    <td>
                      Greater Than
                    </td>
                    <td>
                      (Start Only)
                    </td>
                    <td>
                      {'>2020-01-01'}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {'>='}
                    </td>
                    <td>
                      Greater Than Or Equal To
                    </td>
                    <td>
                      (Start Only)
                    </td>
                    <td>
                      {'>=2020-01-01'}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {'<'}
                    </td>
                    <td>
                      Less Than
                    </td>
                    <td>
                      (Start Only)
                    </td>
                    <td>
                      {'<2020-01-01'}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {'<='}
                    </td>
                    <td>
                      Less Than Or Equal To
                    </td>
                    <td>
                      (Start Only)
                    </td>
                    <td>
                      {'<=2020-01-01'}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {'!'}
                    </td>
                    <td>
                      Not Like
                    </td>
                    <td>
                      (Start Only)
                    </td>
                    <td>
                      {'!UT %B'}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {'NULL'}
                    </td>
                    <td>
                      Empty
                    </td>
                    <td>
                      (Entire Field)
                    </td>
                    <td>
                      {'NULL or !NULL'}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {'&&'}
                    </td>
                    <td>
                      AND
                    </td>
                    <td>
                      (Separator)
                    </td>
                    <td>
                      {'>00:01:00 && <=00:10:00'}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {'||'}
                    </td>
                    <td>
                      OR
                    </td>
                    <td>
                      (Separator)
                    </td>
                    <td>
                      {'>2020-02-01 || <2020-12-31'}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    )
  }
}
