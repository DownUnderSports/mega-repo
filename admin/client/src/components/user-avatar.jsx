import React, { Component } from "react"
import { CardSection, DisplayOrLoading } from "react-component-templates/components"
import { CurrentUser } from 'common/js/contexts/current-user'
import ActiveStorageProvider from "react-activestorage-provider"
import AuthStatus from "common/js/helpers/auth-status"

const contentProps = { className: 'list-group' }

const Upload = ({ upload, reset }) => {
  switch (upload.state) {
    case 'waiting':
      return <p key="waiting">Waiting to upload {upload.file.name}</p>
    case 'uploading':
      return (
        <p key="uploading">
          Uploading {upload.file.name}: {upload.progress}%
        </p>
      )
    case 'error':
      return (
        <p key="error">
          Error uploading {upload.file.name}: {upload.error}
          <button
            className='btn btn-block mt-3 btn-warning'
            onClick={reset}
          >
            Reset Form
          </button>
        </p>
      )
    case 'finished':
      return <p key="finished">Finished uploading {upload.file.name}</p>
    default:
      return <p key="unknown">An Unknown Error Occured</p>
  }
}

const Error = ({ message }) =>
  <div className='row'>
    <div className="col-12 text-danger">
      <p>
       { message }
      </p>
    </div>
  </div>

const arrayPresent = arr => !!arr && !!arr.length && arr

class ActiveStorageRenderer extends Component {
  get onError() {
    return this.props.onError
  }

  get mapErrors() {
    const errors = arrayPresent(this.props.sponsorPhotoErrors)
    return errors && errors.map(this.renderError)
  }

  get mapUploads() {
    const uploads = arrayPresent(this.props.uploads)
    return uploads && uploads.map(this.renderUpload)
  }

  renderError = (message, i) =>
    <Error key={i} message={message} />

  renderUpload = upload =>
    <Upload key={upload.id} upload={upload} reset={this.props.reset} />

  submitPhoto = (e) => {
    try {
      e.preventDefault()
      e.stopPropagation()
      this.props.onStart()
      this.props.handleUpload(this.props.sponsorPhoto).catch(this.onError)
    } catch(err) {
      this.onError(err)
    }
  }

  render() {
    const {
      ready = false,
      onChange,
      sponsorPhoto,
      sponsorPhotoLoading = false,
    } = this.props,
    name = (sponsorPhoto && sponsorPhoto.length)
      ? sponsorPhoto[0].name
      : 'Choose file...',
    buttonDisabled = !ready || !sponsorPhoto || !sponsorPhoto.length

    console.log({...this.props})

    return (
      <div className="row">
        <div className="col form-group">
          <div className="input-group">
            <div className="input-group-prepend">
              <i className="input-group-text material-icons">image</i>
            </div>
            <div className="custom-file">
              <input
                type="file"
                id="sponsor-photo-input"
                name="sponsor-photo-input"
                className="form-control-file"
                placeholder='select sponsor photo'
                onChange={onChange}
                disabled={!ready}
              />
              <label className="custom-file-label" htmlFor="sponsor-photo-input">
                { name }
              </label>
            </div>
          </div>
        </div>
        <div className='col-2 form-group'>
          <button
            className='btn btn-block btn-primary'
            disabled={buttonDisabled}
            onClick={this.submitPhoto}
          >
            Submit
          </button>
        </div>
        <div className="col-12">
          <DisplayOrLoading display={!sponsorPhotoLoading}>
            { this.mapUploads }
            { this.mapErrors }
          </DisplayOrLoading>
        </div>
      </div>
    )
  }
}

export default class UserAvatar extends Component {
  static contextType = CurrentUser.Context

  state = { sponsorPhoto: false, sponsorPhotoErrors: [], sponsorPhotoLoading: false, resetting: false }

  get endpoint() {
    if(this._endpoint) return this._endpoint
    return this._endpoint = {
      path: `/admin/users/${this.props.id}/avatar`,
      model: 'User',
      attribute: 'avatar',
      method: 'PUT'
    }
  }

  get authHeaders() {
    return this._authHeaders
  }

  get headers() {
    if(this._headers) return this._headers
    this._authHeaders = AuthStatus.headerHash
    return this._headers = {
      ...this.authHeaders,
      'X-CSRF-Token': '',
      'Content-Type': 'application/json;charset=UTF-8',
    }
  }

  componentWillUnmount() {
    this._unmounted = true
  }

  shouldComponentUpdate(nextProps, nextState, nextContext) {
    if(nextProps.id !== this.props.id) this._endpoint = null
    if(AuthStatus.headerHash !== this.authHeaders) this._headers = null
    return true
  }

  activeStorageRenderer = (props) =>
    <ActiveStorageRenderer
      setState={this.setState}
      onChange={this.onFileChange}
      onStart={this.onFileSubmitting}
      onError={this.onError}
      reset={this.reset}
      {...props || {}}
      {...this.state}
    />

  reset = () =>
    this.setState({sponsorPhoto: null, resetting: true}, () => {
      setTimeout(this.setState({ resetting: false }))
    })

  onFileSubmitting = () => this.setState({ sponsorPhotoLoading: true })

  onFileChange = (e) => {
    this.setState({ sponsorPhoto: e.currentTarget.files })
  }

  onSubmit = ({ avatar }) => this.setState({
    sponsorPhoto: false,
    sponsorPhotoErrors: [],
    sponsorPhotoLoading: false,
  }, () => avatar && this.props.onAttach && this.props.onAttach(avatar))

  onError = async (err) => {
    if(this._unmounted) return false
    try {
      this.setState({
        sponsorPhotoLoading: false,
        sponsorPhotoErrors: [
          err.request,
          ...((await err.response.json()).errors || [])
        ]
      })
    } catch(_) {
      this.setState({
        sponsorPhotoLoading: false,
        sponsorPhotoErrors: [ err.toString() ]
      })
    }
  }

  render() {
    const {
      avatar,
      avatar_attached
    } = this.props

    return (
      <CardSection
        id="sponsor_photo"
        className='mb-3 border border-info bg-info text-white scroll-margin'
        label='Sponsor Photo'
        contentProps={contentProps}
      >
        {
          avatar_attached && (
            <div className="list-group-item text-center">
              <img src={avatar} className='img-fluid rounded' alt="avatar"/>
            </div>
          )
        }
        <div className="list-group-item">
          <DisplayOrLoading
            display={!this.state.resetting}
          >
            <ActiveStorageProvider
              endpoint={this.endpoint}
              onError={this.onError}
              headers={this.headers}
              onSubmit={this.onSubmit}
              render={this.activeStorageRenderer}
            />
          </DisplayOrLoading>
        </div>
      </CardSection>
    )
  }
}
