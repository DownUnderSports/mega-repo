import React, { Component } from 'react'
import { TextField } from 'react-component-templates/form-components';
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import MeetingSelectField from 'common/js/forms/components/meeting-select-field'
//import authFetch from 'common/js/helpers/auth-fetch'
import canUseDOM from 'common/js/helpers/can-use-dom'

const baseUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/meetings`

export default class MeetingRegistrationUploadForm extends Component {

  constructor(props) {
    super(props)
    this.state = {
      id: props.id || '',
      submitting: false,
      submitted: false,
      message: false,
      file: '',
      errors: '',
      video: '',
    }

    this.setFormAction(this.state)
  }

  componentDidUpdate(props, state) {
    if(props.id !== this.props.id){
      this.setState({
        id: this.props.id
      })
    } else if(this.state.id !== state.id) {
      this.setFormAction(this.state)
    }
  }

  setFormAction = (props) => this.action = `${baseUrl}/${props.id}/registrations`

  setFile = (ev) => {
    const file = ev.target.files[0]
    this.setState({
      file
    })
  }

  setMeeting = (_, target = {}) => this.setState({id: target.value || ''})

  setVideo = (e) => this.setState({video: e.target.value})

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({submitting: true})
    this.handleSubmit()
  }

  handleSubmit = async () => {
    try {
      const data = new FormData()
      data.set('upload[file]', this.state.file)
      if(this.state.video) data.set('video', this.state.video)


      const result =  await fetch(this.action, {
        method: 'POST',
        body: data
      }),
      json = await result.json()

      if(json.message === 'File Uploaded') {
        this.setState({submitting: false, submitted: true, ...json})
      } else {
        this.setState({submitting: false, errors: json.message})
      }
    } catch(e) {
      console.error(e)
    }

  }

  render() {
    const url = `https://admin.downundersports.com/admin/meetings/${this.state.id}/registrations`
    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        <form
          action={this.action}
          autoComplete="off"
          className='payment-form mb-3'
          encType="multipart/form-data"
          method='post'
          onSubmit={this.onSubmit}
        >
          <h3>
            Upload Meeting Registration
          </h3>
          {
            this.state.id && (
              <div className='form-group'>
                <a href={url} target='_download'>
                  { url }
                </a>
              </div>
            )
          }
          {
            this.state.errors ? (
              <div className="alert alert-danger form-group" role="alert">
                {
                  this.state.errors.map((v, k) => (
                    <div className='row' key={k}>
                      <div className="col">
                        { v }
                      </div>
                    </div>
                  ))
                }
              </div>
            ) : (this.state.submitted && (
              <div className="alert alert-success form-group" role="alert">
                { this.state.message }
              </div>
            ))
          }
          <div className='form-group was-validated'>
            <MeetingSelectField
              viewProps={{
                className: 'form-control',
                autoComplete: 'off',
                required: true,
              }}
              label='Select Meeting'
              name='id'
              value={this.state.id}
              onChange={this.setMeeting}
              required
            />
          </div>
          <div className='form-group was-validated'>
            <TextField
              label='File (CSV: duration_percentage, dus_id)'
              name='upload[file]'
              type="file"
              className="form-control"
              onChange={this.setFile}
              required={!this.state.file}
            />
          </div>
          <div className='form-group was-validated'>
            <TextField
              label='Recording Link'
              name='video'
              type="url"
              className="form-control"
              onChange={this.setVideo}
              value={this.state.video}
            />
          </div>
          <button type="submit">
            Submit
          </button>
        </form>
      </DisplayOrLoading>
    )
  }
}
