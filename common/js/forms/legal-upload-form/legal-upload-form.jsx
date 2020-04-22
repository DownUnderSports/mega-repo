import React, { Component } from 'react'
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import ActiveStorageProvider from 'react-activestorage-provider'
import dateFns from 'date-fns'

import { getMimeType, getFileName } from 'common/js/components/pgp-encryptor'

export default class LegalUploadForm extends Component {

  constructor(props) {
    super(props)
    this.state = {
      under_age: this.props.under_age,
      submitting: false,
      submitted: false,
      message: false,
      file: '',
      errors: '',
      storageProviderKey: Math.random(),
      minor_signed_terms_link: "https://signnow.com/s/b1bC7fuX?form=true",
      adult_signed_terms_link: "https://signnow.com/s/UnWReSyz?form=true",
    }
  }

  async componentDidMount() {
    await this.getAction()
  }

  getAction = async () => {
    try {
      const result = await fetch('/api/terms.json')
      let { terms: { minor_signed_terms_link, adult_signed_terms_link } } = await result.json()

      minor_signed_terms_link = minor_signed_terms_link || this.state.minor_signed_terms_link
      adult_signed_terms_link = adult_signed_terms_link || this.state.adult_signed_terms_link

      await (new Promise(r => this.setState({ minor_signed_terms_link, adult_signed_terms_link }, r)))
    } catch(err) {
      console.error(err)
    }
  }

  fileNameValue = () => `${this.props.dus_id}_${this.endpointAttribute()}`

  setFile = async (ev) => {
    const io = ev.target.files[0]
    this.setState({ submitting: true }, async () => {
      try {
        const mimeType = await getMimeType(io, false),
              fileName = getFileName(io.name, mimeType, this.fileNameValue(io.name))

        if(/^application\/pdf$/.test(mimeType) && /\.pdf/.test(fileName)) {
          const file = new File( [ io.slice(0, io.size, mimeType) ], fileName, { type: mimeType } )

          this.setState({ file, submitting: false })
        } else {
          throw new Error("Invalid File Type, PDF documents only")
        }
      } catch(err) {
        this.onError(err)
      }
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

      const result =  await fetch(this.action(), {
              method: 'POST',
              body: data
            }),
            json = await result.json()

      console.log(json)

      this.setState({submitting: false, submitted: (json.message === 'File Uploaded'), ...json}, () => {
        setTimeout(() => {
          if(this.state.submitted) (this.props.onSuccess && this.props.onSuccess())
        }, 2000)
      })
    } catch(e) {
      this.onError(e)
    }
  }

  handleUpload = async (handleUpload) => {
    try {
      await handleUpload([this.state.file])
    } catch (err) {
      this.onError(err)
    }
  }

  selectAge = (ev) => this.setState({under_age: +ev.currentTarget.value})

  onComplete = () => this.props.onSuccess && this.props.onSuccess()

  onSuccess = () =>
    this.setState({ submitting: false, submitted: true, errors: [] }, () => {
      setTimeout(this.onComplete, 2000)
    })

  onError = async (err) =>{
    console.log(err)
    try {
      this.setState({errors: err.message ? [ err.message ] : (await err.response.json()).errors, submitting: false, storageProviderKey: Math.random()})
    } catch(_) {
      this.setState({errors: [ err.toString() ], submitting: false, storageProviderKey: Math.random()})
    }
  }

  action            = () => `/api/departure_checklists/${this.props.id}/upload_legal_form`
  endpointAttribute = () => 'user_signed_terms'
  directUploadsPath = () => `/api/direct_uploads/${this.props.id}/legal_form`

  renderFileInput = (ready) =>
    <input
      type="file"
      id="upload-file"
      name="upload[file]"
      className="form-control-file"
      placeholder='Select Completed Form (PDF)'
      accept="application/pdf"
      onChange={this.setFile}
      required={!this.state.file}
      disabled={!ready}
    />

  fileInputText = () =>
    (this.state.file && this.state.file.name) || 'Select File (PDF)'

  submitButton = (ready, handleUpload) =>
    <button
      className='btn btn-block btn-primary'
      disabled={!ready || !this.state.file}
      onClick={e => {
        e.preventDefault()
        e.stopPropagation()
        this.setState({submitting: !this.showProgress})
        this.handleUpload(handleUpload)
      }}
    >
      Submit
    </button>

  headers = () => ({
    'X-CSRF-Token': '',
    'Content-Type': 'application/json;charset=UTF-8',
  })

  uploadText = () => 'Upload Completed Document:'

  endpointMethod = () => 'POST'
  endpointModel  = () => 'User'

  renderFileUpload = (multiple = false) =>
    <section className="list-group-item">
      <header>
        <h3 className="mb-4">
          { this.uploadText() }
        </h3>
      </header>
      <ActiveStorageProvider
        key={this.state.storageProviderKey}
        directUploadsPath={this.directUploadsPath()}
        endpoint={{
          path: this.action(),
          model: this.endpointModel(),
          attribute: this.endpointAttribute(),
          method: this.endpointMethod()
        }}
        multiple={multiple}
        onError={this.onError}
        headers={this.headers()}
        onSubmit={this.onSuccess}
        render={({ handleUpload, uploads, ready }) => {
          return (
            <div className="row">
              <div className="col form-group">
                <div className="input-group">
                  <div className="input-group-prepend">
                    <i className="input-group-text material-icons">image</i>
                  </div>
                  <div className="custom-file">
                    { this.renderFileInput(ready) }
                    <label className="custom-file-label with-text" htmlFor="upload-file">
                      <span className="custom-file-text">
                        { this.fileInputText() }
                      </span>
                    </label>
                  </div>
                </div>
              </div>
              <div className='col-2 form-group'>
                { this.submitButton(ready, handleUpload) }
              </div>
              <div className="col-12">
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
                {uploads.map(upload => {
                  switch (upload.state) {
                    case 'waiting':
                      return <p key={upload.id}>Waiting to upload {upload.file.name}</p>
                    case 'uploading':
                      return (
                        <p key={upload.id}>
                          Uploading {upload.file.name}: {upload.progress}%
                        </p>
                      )
                    case 'error':
                      return (
                        <p key={upload.id}>
                          Error uploading {upload.file.name}: {upload.error}
                          <button
                            className='btn btn-block mt-3 btn-warning'
                            onClick={() => {
                              this.setState({file: null, resetting: true}, () => {
                                setTimeout(this.setState({resetting: false}))
                              })
                            }}
                          >
                            Reset Form
                          </button>
                        </p>
                      )
                    case 'finished':
                      return <p key={upload.id}>Finished uploading {upload.file.name}</p>
                    default:
                      return <p key={upload.id}>An Unknown Error Occured</p>
                  }
                })}
              </div>
            </div>
          )
        }}
      />
    </section>

  renderFormFields = () =>
    <>
      <section className="list-group-item pb-3">
        <header>
          <h3 className="mb-4">
            Is { this.props.name } currently under 18? (as of {dateFns.format(new Date(), 'MMMM Do, YYYY')})
          </h3>
        </header>
        <div className="row">
          <div className="col-md col-12">
            <div className="input-group mb-3">
              <div className="input-group-prepend">
                <div className="input-group-text">
                  <input
                    name="select_age"
                    id="select_age_yes"
                    type="radio"
                    aria-label={`Checkbox for ${ this.props.name } is currently under 18`}
                    value="1"
                    checked={ (this.state.under_age !== null) && !!this.state.under_age }
                    onChange={this.selectAge}
                  />
                </div>
              </div>
              <label
                htmlFor="select_age_yes"
                className="form-control"
                aria-label={`Yes, ${this.props.name } is currently under 18`}
              >
                Yes, { this.props.name } is currently a minor.
              </label>
            </div>
          </div>
          <div className="col-md col-12">
            <div className="input-group mb-3">
              <div className="input-group-prepend">
                <div className="input-group-text">
                  <input
                    name="select_age"
                    id="select_age_no"
                    type="radio"
                    aria-label={`Checkbox for ${ this.props.name } is currently over 18`}
                    value="0"
                    checked={ (this.state.under_age !== null) && !this.state.under_age }
                    onChange={this.selectAge}
                  />
                </div>
              </div>
              <label
                htmlFor="select_age_no"
                className="form-control"
                aria-label={`No, ${this.props.name } is currently not under 18`}
              >
                No, { this.props.name } is currently a legal adult.
              </label>
            </div>
          </div>
        </div>
      </section>
      {
        this.state.under_age !== null && (
          <>
            <section className="list-group-item">
              <header>
                <h3 className="mb-4">
                  Generate Document to E-Sign:
                </h3>
              </header>
              <a
                target="_sign_now"
                href={this.state.under_age ? this.state.minor_signed_terms_link : this.state.adult_signed_terms_link}
                className="btn btn-block btn-secondary mb-3"
              >
                Click Here
              </a>
            </section>
            { this.renderFileUpload() }
          </>
        )
      }
    </>

  render() {
    return (
      this.state.submitted ? (
        <section className="list-group-item">
          <header>
            <h3 className="mt-3 alert alert-success" role="alert">
              Document Successfully Submitted!
            </h3>
          </header>
          {
            this.props.onSuccess && (
              <p>
                You will be redirected to the checklist page shortly...
              </p>
            )
          }
        </section>
      ) : (
        <>
          <DisplayOrLoading
            display={!this.state.submitting}
            loadingElement={
              <JellyBox className="page-loader" />
            }
          >
            <div></div>
          </DisplayOrLoading>
          <form
            className={this.state.submitting ? 'd-none' : 'm-0 p-0'}
            action={this.action()}
            autoComplete="off"
            encType="multipart/form-data"
            method='post'
            onSubmit={this.onSubmit}
          >
            { this.renderFormFields() }
          </form>
        </>
      )
    )
  }
}
