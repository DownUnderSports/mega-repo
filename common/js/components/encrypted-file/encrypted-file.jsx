import React, { Component } from 'react'
import PGPEncryptor from 'common/js/components/pgp-encryptor'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

const emptyState = { encryptedValue: '', encryptedFile: '', mimeType: '' }

export default class EncryptedFile extends Component {
  state = {...emptyState, files: false, loading: false}

  onChange = (e) => {
    const file = (this.state.files || [])[0]
    file && this.setState({...emptyState, loading: true}, async () => {
      try {
        const { fileName, mimeType, encryptedType, encryptedFile, encryptedFileName } = await PGPEncryptor(file, this.props.fileName || '', !!this.props.allowUnknown)
        this.setState({
          fileName,
          mimeType,
          encryptedType,
          encryptedFile,
          encryptedFileName,
          loading: false
        })
      } catch (e) {
        console.log(e)
        this.setState({ errors: [ e.toString() ] })
      }
    })
  }

  componentDidUpdate({ value, mimeType }, { encryptedFile, mimeType: stateMimeType, files }) {
    if(
        this.state.files
        && this.state.files.length
        && (
          !files
          || files.length !== this.state.files.length
          || files[0] !== this.state.files[0]
        )
    ){
      this.onChange()
    } else if(
      (this.state.encryptedFile !== encryptedFile)
      || (this.state.mimeType !== stateMimeType)
    ) {
      this.props.onChange && this.props.onChange(false, {
        value: this.state.encryptedFile,
        fileName: this.state.fileName,
        mimeType: this.state.mimeType,
        encryptedFileName: this.state.encryptedFileName,
        encryptedMimeType: this.state.encryptedMimeType,
      })
    } else if(
      (
        (this.props.value !== value)
        || (this.props.mimeType !== mimeType)
      ) && (
        (this.props.value !== this.state.encryptedFile)
        || (this.props.mimeType !== this.state.mimeType)
      )
    ) {
      this.setState({ encryptedFile: this.props.value, mimeType: this.props.mimeType })
    }
  }

  getBase64 = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.setState({
      showBase64: true
    }, () => {
      if(this.state.encryptedFile) {
        const reader = new FileReader()
        reader.onload = () => this.setState({encryptedValue: reader.result})
        reader.readAsDataURL(this.state.encryptedFile)
      } else {
        this.setState({encryptedValue: '', showBase64: false})
      }
    })
  }

  // downloadFile = (ev) => {
  //   ev.preventDefault()
  //   ev.stopPropagation()
  //   el = document.createElement('a')
  //   a.dataset.downloadurl = ['application/pgp-encrypted', a.download, a.href].join(':')
  // }

  render() {
    return this.state.loading ? (
      <JellyBox className="page-loader" />
    ) : (
      <div className={this.props.className || undefined}>
        <div className="input-group">
          <div className="input-group-prepend">
            <i className="input-group-text material-icons">image</i>
          </div>
          <div className="custom-file">
            <input
              type="file"
              id={this.props.id || 'filePicker'}
              name={this.props.name || 'filePicker'}
              className="form-control-file"
              placeholder='select sponsor photo'
              onChange={(e) => this.setState({files: e.currentTarget.files})}
              accept={this.props.accept || '*/*'}
            />
            <label className="custom-file-label" htmlFor={this.props.id || 'filePicker'}>
              {
                (
                  this.state.files && this.state.files.length
                ) ? this.state.files[0].name : 'Choose file...'
              }
            </label>
          </div>
        </div>
        <div className="row mt-2">
          <div className="col">
            <small className="form-text">
              <h6 className="text-center">
                <span className="text-danger">WARNING:</span> The file selector above may cause your browser to freeze for a brief period while the selected file is being encrypted.
              </h6>
              <strong><i>This is perfectly normal, please don't worry.</i></strong> If you have any issues, please contact our office by calling <a href="tel:+1-435-753-4732">(435) 753-4732</a> or emailing <a href="mailto:mail@downundersports.com" target="_blank" rel="noopener noreferrer">mail@downundersports.com</a>. For more information on the ecryption technique being used, visit <a href="https://www.openpgp.org/" target="_blank" rel="noopener noreferrer">www.openpgp.org</a>
            </small>
          </div>
        </div>
        {
          this.state.errors && (
            <div className="row">
              {
                this.state.errors.map((err, i) => (
                  <div key={i} className="col-12">
                    <div className="mt-3 alert alert-danger" role="alert">
                      { err }
                    </div>
                  </div>
                ))
              }
            </div>
          )
        }
        {
          this.props.showInfo && this.state.encryptedFile && (
            <>
              <hr />
              <h1>Encryption Info</h1>
              <label>Name:</label>
              <input className="form-control form-group" value={ this.state.fileName } readOnly />
              <label>PGP Name:</label>
              <input className="form-control form-group" value={ this.state.encryptedFileName } readOnly />
              <label>Mime Type:</label>
              <input className="form-control form-group" value={ this.state.mimeType } readOnly />
              <label>Result:</label>
              <div className="row form-group">
                <div className="col">
                  <a
                    className="btn btn-info mr-3"
                    download={this.state.encryptedFile.name}
                    data-downloadurl={[
                      this.state.encryptedMimeType,
                      this.state.encryptedFile.name,
                      URL.createObjectURL(this.state.encryptedFile)
                    ].join(':')}
                    href={URL.createObjectURL(this.state.encryptedFile)}
                  >
                    Download
                  </a>
                </div>
              </div>
              {
                this.state.showBase64 ? (
                  <textarea className="form-control vh-25" value={ this.state.encryptedValue } readOnly />
                ) : (
                  <button className="btn btn-block btn-warning" type="button" onClick={this.getBase64}>Show Base64</button>
                )
              }
            </>
          )
        }
      </div>
    )
  }
}
