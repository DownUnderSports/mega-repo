import React, { Component } from 'react'
//import authFetch from 'common/js/helpers/auth-fetch'
import canUseDOM from 'common/js/helpers/can-use-dom'
import { DisplayOrLoading, CardSection } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import { Objected } from 'react-component-templates/helpers';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'


const baseUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/users/%id%/mailings.json`

export default class UserMailings extends Component {

  constructor(props) {
    super(props)
    this.state = { mailings: [], allMailings: [], reloading: true }
  }

  async componentDidMount(){
    this._isMounted = true
    await this.getMailings()
  }

  async componentWillUnmount(){
    this.abortFetch()
    this._isMounted = false
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.getMailings()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  filter = (val) => {

    this.setState({
      mailings: val ? this.state.allMailings.filter((m) => {
        for(let k in Objected.filterKeys(m, ['id', 'user_id'])) {
          if((k === 'is_home') && (m[k] ? 'home' : 'school').includes(val)) return true
          else if((k === 'failed') && (m[k] ? 'failed' : 'successful').includes(val)) return true
          else if(m.hasOwnProperty(k) && `${m[k] || ''}`.toLowerCase().includes(val)) return true
        }
        return false
      }) : [...this.state.allMailings]
    })
  }

  getMailings = async () => {
    if(this._isMounted) {
      this.setState({reloading: true})
      try {
        this.abortFetch()
        if(!this.props.id) throw new Error('UserMailings: No User ID')
        this._fetchable = fetch(baseUrl.replace('%id%', this.props.id), {timeout: 5000})
        const result = await this._fetchable,
              retrieved = await result.json()

        if(this._isMounted) {
          this.setState({
            reloading: false,
            allMailings: [...retrieved.mailings],
            ...retrieved,
          })
        }

      } catch(e) {
        if(this._isMounted) {
          console.error(e)
          this.setState({
            reloading: false,
            mailings: [],
            allMailings: [],
          })
        }
        return false
      }
    }
    return true
  }

  render() {
    return (
      <DisplayOrLoading
        display={!this.state.reloading}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        <CardSection
          className='mb-3'
          label='Mailings'
          subLabel={
            <div className='row'>
              <div className='col text-center'>
                <TextField
                  name='dus_id'
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
          {
            this.state.mailings.map(({sent, category, address, failed, is_home}, k) => (
              <div key={k} className={`list-group-item p-0 ${k > 0 ? 'pt-2' : ''} border-0`}>
                  <div className="col-12 border-bottom">
                    <div className={`row ${(failed ? 'bg-danger' : 'bg-secondary')} text-light`}>
                      <div className='col-3 border-right'>{ sent }</div>
                      <div className='col border-left'>{ category } - {failed ? 'Failed' : 'Successful'}</div>
                    </div>
                  </div>
                  <div className="col-12 bg-dark text-white">
                    {address} ({is_home ? 'Home' : 'School'})
                  </div>
              </div>
            ))
          }
        </CardSection>
      </DisplayOrLoading>
    )
  }
}
