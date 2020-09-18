import React, { Component } from 'react'
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

export default class AssignmentsUploadForm extends Component {
  get prefix() {
    return String(this.props.prefix || "")
  }

  constructor(props) {
    super(props)
    this.state = {
      submitting: false,
      submitted: false,
      message: false,
      file: '',
      errors: '',
    }
  }

  setFile = (ev) => {
    const file = ev.target.files[0]
    this.setState({
      file
    })
  }

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({submitting: true})
    this.handleSubmit()
  }

  handleSubmit = async () => {
    try {
      const data = new FormData()
      data.set('upload[file]', this.state.file)

      const result =  await fetch(this.props.url, {
        method: 'POST',
        body: data
      }),
      json = await result.json()

      console.log(json)

      this.setState({submitting: false, submitted: (json.message === 'File Uploaded'), ...json}, this.props.reload)
    } catch(e) {
      console.error(e)
      this.setState({submitting: false, errors: [e.message]})
    }

  }

  render() {
    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        <form
          action={this.props.url}
          autoComplete="off"
          className="row"
          encType="multipart/form-data"
          method='post'
          onSubmit={this.onSubmit}
        >
          <div className="col-md col-xl-8">
            <div className="input-group">
              <div className="input-group-prepend">
                <i className="input-group-text material-icons">attach_file</i>
              </div>
              <div className="custom-file">
                <input
                  type="file"
                  id={`${this.prefix}upload-file`}
                  name="upload[file]"
                  className="form-control-file"
                  placeholder='select sponsor photo'
                  onChange={this.setFile}
                  required={!this.state.file}
                />
                <label className="custom-file-label with-text" htmlFor={`${this.prefix}upload-file`}>
                  <span className="custom-file-text">
                    {
                      (this.state.file && this.state.file.name) || 'Select File (CSV: staff_dus_id, dus_id)'
                    }
                  </span>
                </label>
              </div>
            </div>
            {
              this.state.errors ? (
                <div className="alert alert-danger form-group mt-3" role="alert">
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
              ) : (
                this.state.submitted && (
                  <div className="alert alert-success form-group mt-3" role="alert">
                    { this.state.message }
                  </div>
                )
              )
            }
          </div>
          <div className="col-auto">
            <button className='btn btn-primary' type="submit">
              Submit
            </button>
          </div>

        </form>

      </DisplayOrLoading>
    )
  }
}
