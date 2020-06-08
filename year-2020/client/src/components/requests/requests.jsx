import React, { Component } from 'react'
import { DisplayOrLoading, CardSection } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import { Objected } from 'react-component-templates/helpers';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

const baseUrl = '/admin/users'

export default class Requests extends Component {
  constructor(props) {
    super(props)
    this.state = { requests: [], allRequests: [], reloading: true }
  }

  async componentDidMount(){
    this._isMounted = true
    await this.getRequests()
  }

  componentWillUnmount(){
    this.abortFetch()
    this._isMounted = false
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.getRequests()
  }

  capitalize(str) {
    return str[0].toUpperCase() + str.slice(1)
  }

  abortFetch = () => {
    if(this._fetchable) {
      if(!this._fetchable.abort) console.log(this._fetchable, fetch)
      this._fetchable.abort()
    }
  }

  forceGetRequests = () => this.getRequests(true)

  getRequests = async (force = false) => {
    if(this._isMounted){
      this.setState({reloading: true})
      try {
        this.abortFetch()
        if(!this.props.id) throw new Error(`Traveler Requests: No User ID`)
        this._fetchable = fetch(`${baseUrl}/${this.props.id}/requests.json?force=${force ? 1 : 0}`, {timeout: 5000})
        const result = await this._fetchable,
              retrieved = await result.json()


        if(this._isMounted) {
          this.setState({
            reloading: false,
            allRequests: [...retrieved.requests],
            ...retrieved,
          })
        }

      } catch(e) {
        if(this._isMounted) {
          console.error(e)
          this.setState({
            reloading: false,
            allRequests: [],
            requests: [],
          })
        }
        return false
      }
    }
    return true
  }

  filter = (val) => {
    const reg = val && new RegExp(val, 'i')
    this.setState({
      requests: val ? this.state.allRequests.filter((m) => {
        for(let k in Objected.filterKeys(m, ['id', 'traveler_id'])) {
          if(m.hasOwnProperty(k) && reg.test(`${m[k] || ''}`)) return true
        }
        return false
      }) : [...this.state.allRequests]
    })
  }

  render() {
    return (
      <DisplayOrLoading
        display={!this.state.reloading}
        request='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        <CardSection
          className='mb-3'
          label={
            <div className="row">
              <div className="col-auto"></div>
              <div className="col">Traveler Requests</div>
              <div className="col-auto">
                <i className="material-icons clickable" onClick={this.forceGetRequests}>
                  refresh
                </i>
              </div>
            </div>
          }
          subLabel={
            <div className='row'>
              <div className='col text-center'>
                <TextField
                  name={`search[requests]`}
                  onChange={(e) => this.filter(e.target.value)}
                  className='form-control'
                  autoComplete='off'
                  skipExtras
                />
              </div>
            </div>
          }
          contentProps={{className: 'list-group'}}
        >
          <table className="table table-bordered mb-0">
            <colgroup>
              <col width="100" />
              <col width="300" />
            </colgroup>
            <thead>
              <tr>
                <th>
                  Category
                </th>
                <th>
                  Details
                </th>
              </tr>
            </thead>
            <tbody>
              {
                this.state.requests.map((m) => (
                  <tr key={m.id}>
                    <td>
                      { this.capitalize(m.category) }
                    </td>
                    <td>
                      <pre>{m.details}</pre>
                    </td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </CardSection>
      </DisplayOrLoading>
    )
  }
}
