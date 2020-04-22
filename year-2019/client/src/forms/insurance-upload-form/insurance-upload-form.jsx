import React from 'react'
import LegalUploadForm from 'forms/legal-upload-form'
import { getMimeType, getFileName } from 'common/js/components/pgp-encryptor'
import MethodLink from 'common/js/forms/components/method-link'

export default class InsuranceUploadForm extends LegalUploadForm {
  constructor(props) {
    super(props)
    this.state = {
      submitting: false,
      submitted: false,
      message: false,
      can_delete: false,
      files: [],
      proofs: [],
      errors: '',
      storageProviderKey: Math.random(),
    }
  }

  getAction         = () => Promise.resolve()
  deletable         = () => false

  action            = () => `/admin/users/${this.props.dus_id}/insurance_proofs`

  deleteFileAction  = (id) => `${this.action()}/${id || ''}`

  endpointAttribute = () => 'insurance_proofs'

  directUploadsPath = () => `/rails/active_storage/direct_uploads/insurance_proofs/${this.props.dus_id}`

  renderFormFields  = () => this.state.showUpload ? this.renderFileUpload(true) : this.renderStatus()

  resetFormState    = () => this.setState({ loading: true, submitted: false, showUpload: false, showFile: false, files: [], errors: null }, this.componentDidMount)

  setFile = (ev) => {
    const inputs = ev.target.files,
          files  = []
    this.setState({ submitting: true }, async () => {
      try {
        console.log(inputs)
        for (let i = 0; i < inputs.length; i++) {
          const io       =  inputs[i],
                mimeType =  await getMimeType(io, false),
                fileName =  getFileName(
                              io.name,
                              mimeType,
                              `${this.props.dus_id}_${this.endpointAttribute()}_${i}`
                            )
          console.log(mimeType, fileName)
          if(
            (/^application\/pdf$/.test(mimeType) && /\.pdf/.test(fileName))
            || (/^image\/.*$/.test(mimeType))
          ) {
            files.push(
              new File( [ io.slice(0, io.size, mimeType) ], fileName, { type: mimeType } )
            )
          } else {
            throw new Error("Invalid File Type, PDF documents and images only")
          }
        }
        this.setState({files, submitting: false})
      } catch(err) {
        this.onError(err)
      }
    })
  }

  handleSubmit = async () => {
    try {
      const data = new FormData()
      data.set('upload[files][]', this.state.files)

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
    } catch(err) {
      this.onError(err)
    }
  }

  handleUpload = async (handleUpload) => {
    try {
      await handleUpload(this.state.files)
    } catch (err) {
      this.onError(err)
    }
  }

  renderFileInput = (ready) =>
    <input
      type="file"
      id="upload-file"
      name="upload[files]"
      className="form-control-files"
      accept="application/pdf,image/*"
      multiple
      onChange={this.setFile}
      required={!this.state.files}
      disabled={!ready}
    />

  fileInputText = () =>
    (
      this.state.files
      && this.state.files.length
      && this.state.files.map((f) => f.name).join(', ')
    ) || 'Select File(s)'

  submitButton = (ready, handleUpload) =>
    <button
      className='btn btn-block btn-primary'
      disabled={!ready || !this.state.files || !this.state.files.length}
      onClick={e => {
        e.preventDefault()
        e.stopPropagation()
        this.handleUpload(handleUpload)
      }}
    >
      Submit
    </button>



  renderStatus  = () =>
    <section className="list-group-item">
      <header>
        <h2>
          For: { this.state.user_name }
        </h2>
        <hr/>
        <h3 className={this.state.status === 'Completed' ? 'text-success' : this.state.status === 'Extra Processing' ? 'text-danger' : ''}>
          { this.state.status || 'Unknown'}
        </h3>
      </header>
      <div className="row">
        <div className="col-lg form-group">
          <button type="button" className="btn btn-block btn-warning" onClick={this.showForm}>
            Add File
          </button>
        </div>
        {
          this.state.proofs && !!this.state.proofs.length && (
            this.state.showFile ? (
              <div className="col-12">
                {
                  this.state.proofs.map(
                    ({link, id}, i) =>
                      <div className="row form-group" key={i}>
                        <div className={`col-${this.state.can_delete ? '9' : '12'}`}>
                          {
                            /\.pdf/.test(link) ? (
                              <object
                                data={link}
                                width="100%"
                                height="500"
                                type="application/pdf"
                              >
                                <a href={link}>Open Direct File</a>
                              </object>
                            ) : (
                              <img
                                className="img-fluid"
                                src={link}
                                alt="insurance-proof"
                              />
                            )
                          }
                        </div>
                        {
                          this.state.can_delete && (
                            <div className="col-3">
                              <MethodLink
                                url={this.deleteFileAction(id)}
                                method="DELETE"
                                confirmationMessage={"Are you sure you want to delete this file?\nThis cannot be undone"}
                                onSuccess={this.onComplete}
                                className="btn btn-block btn-danger"
                              >
                                Delete Image
                              </MethodLink>
                            </div>
                          )
                        }
                      </div>
                  )
                }
              </div>
            ) : (
              <div className="col-lg form-group">
                <button type="button" className="btn btn-block btn-info" onClick={this.showFile}>
                  Open File(s)
                </button>
              </div>
            )
          )
        }
      </div>
      {
        this.props.children
      }
    </section>
}
