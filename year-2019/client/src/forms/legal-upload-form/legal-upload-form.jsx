import React from 'react'
import AuthStatus from 'common/js/helpers/auth-status'
import { Link } from 'react-component-templates/components'
import LegalUploadForm from 'common/js/forms/legal-upload-form'

export default class AdminLegalUploadForm extends LegalUploadForm {
  get showProgress() {
    return true
  }

  async componentDidMount() {
    this._isMounted = true

    try {
      if(!this.props.dus_id) return false
      await (() => new Promise((res, rej) => {
        this.setState({loading: true}, async () => {
          try {
            const result = await (this._fetchingResource = fetch(this.action())),
                  retrieved = await result.json()

            if(this._isMounted) this.setState(retrieved, res)
          } catch(e) {
            console.log(e)
            res()
          }
        })
      }))()
      return true
    } catch (err) {
      console.log(err)
    }

    if(this._isMounted) this.setState({loading: false})
  }

  componentWillUnmount() {
    this._isMounted = false
    if(this._fetchingResource) this._fetchingResource.abort()
  }

  getAction         = () => Promise.resolve()
  action            = () => `/admin/users/${this.props.dus_id}/legal_form`

  endpointAttribute = () => 'signed_terms'

  directUploadsPath = () => `/rails/active_storage/direct_uploads/legal_form/${this.props.dus_id}`

  onComplete        = () => this.props.onSuccess ? this.props.onSuccess() : this.resetFormState()

  resetFormState    = () => this.setState({ loading: true, submitted: false, showUpload: false, showFile: false, file: null, errors: null }, this.componentDidMount)

  headers           = () => ({
                              ...AuthStatus.headerHash,
                              'X-CSRF-Token': '',
                              'Content-Type': 'application/json;charset=UTF-8',
                            })

  renderFormFields  = () => this.state.showUpload ? this.renderFileUpload() : this.renderStatus()
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

  deletable = () => this.state.status !== "Completed"

  signingLink = () => this.state.under_age ? "https://signnow.com/s/xKvii5n8?form=true" : "https://signnow.com/s/UVw82zDB?form=true"

  renderStatusText = () =>
    <Link to={this.signingLink()}>
      { this.state.status || 'Unknown' }
    </Link>

  renderStatus  = () =>
    <section className="list-group-item">
      <header>
        <h3>
          { this.renderStatusText() }
        </h3>
      </header>
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
    </section>
}
