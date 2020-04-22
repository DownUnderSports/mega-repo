import React, { Component } from 'react';
import { DisplayOrLoading, CardSection, Link } from 'react-component-templates/components';
import SchoolForm from 'forms/school-form'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

export const schoolsUrl = '/admin/schools/:id.json'

export default class SchoolInfo extends Component {

  constructor(props) {
    super(props)
    this.state = { school: {}, fullStats: false, reloading: !!this.props.id, showForm: !this.props.id }
  }

  async componentDidMount(){
    if(this.props.id) await this.getSchool()
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.getSchool()
  }

  componentWillUnmount() {
    this._unmounted = true
    this.abortFetch()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  getSchool = async (showForm = false) => {
    if(this._unmounted) return false
    if(!this.props.id) return this.setState({showForm})
    this.setState({reloading: true})
    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('School Info: No School ID')
      this._fetchable = fetch(schoolsUrl.replace(':id', this.props.id), {timeout: 5000})
      const result = await this._fetchable,
            retrieved = await result.json()

      this._unmounted || this.setState({
        reloading: false,
        school: retrieved,
        showForm
      })

      if(this.props.afterFetch) this.props.afterFetch({school: retrieved})
    } catch(e) {
      console.error(e)
      this._unmounted || this.setState({
        reloading: false,
        school: {},
      })
    }
  }

  openSchoolForm = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.getSchool(true)
  }

  requestInfokit = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.setState({reloading: true})
    try {
      const has_infokit = !!this.state.school.has_infokit
      if(!has_infokit || window.confirm('Are you sure you want to resend this infokit?')) {
        await fetch(`${schoolsUrl.replace(':id', `${this.props.id}/infokit`)}${has_infokit ? '?force=true' : ''}`)
        await this.getSchool()
      } else {
        throw new Error('Already Requested')
      }
    } catch(e) {
      console.error(e)
      this._unmounted || this.setState({
        reloading: false,
      })
    }
  }

  cancelSchool = async (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    if(!this.state.school) return false
    if(this.state.school.interest_id === 1) return alert('You must set an appropriate interest level first')
    if(window.confirm(`Are you sure you want to cancel ${this.state.school.title} ${this.state.school.first} ${this.state.school.middle} ${this.state.school.last} ${this.state.school.suffix}?`)) {
      try {
        this.setState({reloading: true})
        await fetch(schoolsUrl.replace(':id', `${this.props.id}/cancel`), {
          method: 'DELETE',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          },
          body: JSON.stringify({
            cancel: true
          })
        });

        await this.getSchool()
      } catch (err) {
        this._unmounted || this.setState({reloading: false})
        try {
          const resp = await err.response.json()
          console.log(resp)
          alert(resp.error)
        } catch(e) {
          alert(e.message)
        }
      }
    }
  }

  phoneFormat(phone) {
    phone = String(phone || '')
    switch (true) {
      case /^\+/.test(phone):
        return phone
      case /^0/.test(phone):
        return `+61${phone.replace(/^0|[^0-9]/g, '')}`
      case /^[0-9]{3}-?[0-9]{3}-?[0-9]{4}$/.test(phone):
        return `+1-${phone}`;
      default:
        return phone
    }
  }

  render() {
    const {
      school: {
        pid,
        name,
        allowed,
        allowed_home,
        closed,
        address,
      },
      reloading = false,
      showForm
    } = this.state || {}

    return (
      <DisplayOrLoading
        display={!reloading}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        {
          showForm ? (
            <SchoolForm
              id={ this.props.formId || this.props.id }
              onSuccess={ this.props.onSuccess || (() => this.getSchool()) }
              onCancel={ this.props.onCancel || (() => this.setState({showForm: false}))}
              url={ this.props.url || '' }
              school={ (this.state || {}).school || {} }
            />
          ) : (
            <CardSection
              className={`mb-3 ${!allowed && (allowed_home ? 'alert-warning' : 'alert-danger')}`}
              label={<div>
                <Link className='float-left' onClick={this.openSchoolForm} to={window.location.href}>Edit</Link>
                {this.props.header || 'School Info'}
                <Link className='float-right' to={`/admin/schools/${pid}`}>{pid}</Link>
              </div>}
              contentProps={{className: 'list-group'}}
            >
              <div className="list-group-item">
                <strong>Name:</strong> {name}
              </div>
              <div className="list-group-item">
                <div className="row">
                  <div className="col-md col-12">
                    <strong>Allowed:</strong> {allowed ? 'Yes' : 'No'}
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong>Allowed Home:</strong> {allowed_home ? 'Yes' : 'No'}
                    <hr className='d-md-none'/>
                  </div>
                  <div className="col-md col-12">
                    <strong>Closed:</strong> {closed ? 'Yes' : 'No'}
                  </div>
                </div>
              </div>
              <div className="list-group-item">
                <div className="row">
                  <div className="col">
                    <strong>Address:</strong> {address}
                  </div>
                </div>
              </div>
            </CardSection>
          )
        }
      </DisplayOrLoading>
    );
  }
}
