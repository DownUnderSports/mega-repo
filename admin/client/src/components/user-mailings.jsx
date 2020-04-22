import React, { Component } from 'react'
import { DisplayOrLoading, CardSection } from 'react-component-templates/components';
import { TextField } from 'react-component-templates/form-components';
import { Objected } from 'react-component-templates/helpers';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import MailingForm from 'forms/mailing-form'


const baseUrl = '/admin/users/%id%/mailings.json'

export default class UserMailings extends Component {

  constructor(props) {
    super(props)
    this.state = { mailings: [], allMailings: [], reloading: true, canAdd: false, openForm: false }
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

  switchToHome = async (ev) => {
    if(this._isMounted) this.setState({reloading: true})

    try {
      const id = ev.currentTarget.dataset.id
      if(!id) throw new Error('UserMailings: No ID for Home Swap')
      this.abortFetch()

      await fetch(baseUrl.replace('%id%', this.props.id).replace('.json', '') + `/${id}`, {
              method: 'PATCH',
              headers: {
                "Content-Type": "application/json; charset=utf-8"
              },
              body: JSON.stringify({ switch_to_home: true })
            })

      if(this._isMounted) return await this.getMailings()
    } catch(e) {
      console.error(e)

      if(this._isMounted) this.setState({ reloading: false })

      return false
    }
    return true
  }

  forceGetMailings = () => this.getMailings(true)

  getMailings = async (force = false) => {
    if(this._isMounted) {
      this.setState({reloading: true})
      try {
        this.abortFetch()
        if(!this.props.id) throw new Error('UserMailings: No User ID')
        this._fetchable = fetch(`${baseUrl.replace('%id%', this.props.id)}?force=${force ? 1 : 0}`, {timeout: 5000})
        const result = await this._fetchable,
              retrieved = await result.json()

        if(this._isMounted) {
          this.setState({
            reloading: false,
            allMailings: [...retrieved.mailings],
            ...retrieved,
            canAdd: !!retrieved.is_admin
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

  newMailing = () => this.setState({ openForm: 'new' })
  editMailing = (ev) => {
    try {
      const id = ev.currentTarget.dataset.id
      if(!id) throw new Error('UserMailings: No ID')

      if(this._isMounted) this.setState({ openForm: +id })
    } catch(e) {
      console.error(e)

      if(this._isMounted) this.setState({ openForm: false })

      return false
    }
    return true
  }
  closeForm = () => this.setState({ openForm: false })
  onNewMailSuccess = () => this.setState({ openForm: false}, this.getMailings)

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
          label={
            <div className="row">
              <div className="col-auto"></div>
              <div className="col">Mailings</div>
              <div className="col-auto">
                <i className="material-icons clickable" onClick={this.forceGetMailings}>
                  refresh
                </i>
              </div>
            </div>
          }
          subLabel={
            <div className='row'>
              <div className='col text-center'>
                <TextField
                  name='search'
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
            this.state.mailings.map(({id, sent, category, address, failed, is_home, form_attributes = {}}, k) => (
              <div key={k} className={`list-group-item p-0 ${k > 0 ? 'pt-2' : ''} border-0`}>
                  <div className="col-12 border-bottom">
                    {
                      (this.state.openForm === id)
                        ? <MailingForm onCancel={this.closeForm} onSuccess={this.onNewMailSuccess} userId={this.props.id} id={id} mailing={form_attributes} />
                        : (
                            <div className={`row ${(failed ? 'bg-danger' : 'bg-secondary')} text-light`}>
                              <div className='col-3 border-right'>{ sent }</div>
                              <div className='col border-left'>{ category } - {failed ? 'Failed' : 'Successful'}</div>
                              {
                                !sent && (
                                  !!this.state.canAdd
                                    ? (
                                        <div className="col-auto pr-0">
                                          <button
                                            data-id={id}
                                            className="btn btn-danger py-0 px-1 rounded-0"
                                            onClick={this.editMailing}
                                          >
                                            Update Address
                                          </button>
                                        </div>
                                      )
                                    : (
                                        !/invite/i.test(category) && (
                                          <div className="col-auto pr-0">
                                            <button
                                              data-id={id}
                                              className="btn btn-danger py-0 px-1 rounded-0"
                                              onClick={this.switchToHome}
                                            >
                                              { !is_home ? 'Switch to Home' : 'Update Address' }
                                            </button>
                                          </div>
                                        )
                                      )
                                )
                              }
                            </div>
                          )
                    }
                  </div>
                  <div className="col-12 bg-dark text-white">
                    <div className="row">
                      <div className="col">
                        {address} ({is_home ? 'Home' : 'School'})
                      </div>
                    </div>
                  </div>
              </div>
            ))
          }
          {
            !!this.state.canAdd && (
              (this.state.openForm === "new")
                ? <MailingForm onCancel={this.closeForm} onSuccess={this.onNewMailSuccess} userId={this.props.id} />
                : <button className="btn-block btn-primary mt-2" onClick={this.newMailing}>Add New Mailing</button>
            )
          }
        </CardSection>
      </DisplayOrLoading>
    )
  }
}
