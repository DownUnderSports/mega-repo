import React from 'react'
import AuthStatus from 'common/js/helpers/auth-status'
import LegalUploadForm from 'common/js/forms/legal-upload-form'
import { TextField } from 'react-component-templates/form-components';

export default class EventResultUploadForm extends LegalUploadForm {
  get showProgress() {
    return true
  }

  async componentDidMount() {
    this._isMounted = true

    try {
      if(!this.props.eventId) return false
      await (() => new Promise((res, rej) => {
        this.setState({loading: true}, async () => {
          try {
            const result = await (this._fetchingResource = fetch(this.getAction())),
                  retrieved = await result.json()

            if(this._isMounted) this.setState(retrieved, res)
          } catch(e) {
            console.error(e)
            res()
          }
        })
      }))()
      return true
    } catch (err) {
      console.error(err)
    }

    if(this._isMounted) this.setState({ loading: false })
  }

  componentWillUnmount() {
    this._isMounted = false
    if(this._fetchingResource) this._fetchingResource.abort()
  }

  getLinks          = () => Promise.resolve()

  endpointMethod    = () => this.props.id ? 'PUT' : 'POST'

  endpointModel     = () => 'static_file'

  fileNameValue     = () => false

  getAction         = () => `/admin/traveling/event_results/${this.props.eventId}/static_files/${this.props.id || 'new'}`

  action            = () => `/admin/traveling/event_results/${this.props.eventId}/static_files/${this.props.id || ''}?name=${encodeURIComponent(this.state.name)}`

  endpointAttribute = () => 'result_file'

  directUploadsPath = () => `/rails/active_storage/direct_uploads/event_result/${this.props.eventId}/static_files/${this.props.id || ''}`

  onComplete        = () => this.props.onSuccess ? this.props.onSuccess() : this.resetFormState()

  resetFormState    = () => this.setState({ loading: true, submitted: false, showUpload: false, showFile: false, file: null, errors: null }, this.componentDidMount)

  headers           = () => ({
                              ...AuthStatus.headerHash,
                              'X-CSRF-Token': '',
                              'Content-Type': 'application/json;charset=UTF-8',
                            })

  renderFormFields  = () =>
    this.state.showUpload
      ? <>{this.renderNameInput()}{this.renderFileUpload()}</>
      : this.renderStatus()


  renderNameInput   = () =>
    <div className="list-group-item">
      <TextField
        name="name"
        label="Display Name"
        className="form-control"
        value={this.state.name}
        onChange={this.onNameChange}
        required
      />
    </div>

  onNameChange = (ev) => this.setState({name: ev.currentTarget.value || ''})

  uploadText = () => 'Upload Result File:'

  showForm = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.setState({ showUpload: true, showFile: false })
  }

  showFile = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.setState({ showUpload: false, showFile: true })
  }

  deleteFile = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.setState({ submitting: true, errors: []}, async () => {
      try {
        await fetch(this.action(), {
          method: 'DELETE',
          headers: {
            "Content-Type": "application/json; charset=utf-8"
          }
        })

        this.onSuccess()
      } catch(err) {
        this.onError(err)
      }
    })
  }

  deletable = () => true

  renderStatusText = () => `Event Result File: ${this.state.name || 'New'}`

  renderStatus  = () =>
    <section className="list-group-item">
      <div className="row">
        <div className="col-md-auto">
          <h3>
            { this.renderStatusText() }
          </h3>
        </div>
        <div className="col">
          {
            this.state.showFile ? (
              /\.pdf/.test(this.state.link) ? (

                <object
                  data={this.state.link}
                  width="100%"
                  height="500"
                  type="application/pdf"
                >
                  <a href={this.state.link}>Open Direct File</a>
                </object>
              ) : (
                <img
                  className="img-fluid"
                  src={this.state.link}
                  alt="legal-document"
                />
              )
            ) : (
              <div className="row">
                {
                  (this.state.status !== "Completed") && (
                    <div className="col-lg form-group">
                      <button type="button" className="btn btn-block btn-warning" onClick={this.showForm}>
                        Open Form
                      </button>
                    </div>
                  )
                }
                {
                  this.state.link && (
                    <div className="col-lg form-group">
                      <button type="button" className="btn btn-block btn-info" onClick={this.showFile}>
                        Open File
                      </button>
                      {
                        this.deletable() && (
                          <button type="button" className="btn btn-block btn-danger" onClick={this.deleteFile}>
                            Delete File
                          </button>
                        )
                      }
                    </div>
                  )
                }
              </div>
            )
          }
        </div>
      </div>
    </section>
}
