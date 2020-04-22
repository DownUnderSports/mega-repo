import React, { PureComponent } from 'react'

export default class Colors extends PureComponent {
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
                Colors:
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
                  <tr key="border-active">
                    <td className='border-top-0'>
                      <span
                        className="border-active bg-light"
                        style={{
                          display: 'inline-block',
                          width: 50,
                          height: 50,
                        }}
                      >
                      </span>
                    </td>
                    <td className="border-top-0">
                      Last Visited Row
                    </td>
                  </tr>
                  {
                    this.props.colors.map((color, i) => (
                      <tr key={`${color.className}.${color.value}`}>
                        <td>
                          <span
                            className={color.className}
                            style={{
                              display: 'inline-block',
                              width: 50,
                              height: 50,
                              background: color.value
                            }}
                          >
                          </span>
                        </td>
                        <td>
                          { color.description }
                        </td>
                      </tr>
                    ))
                  }
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    )
  }
}
