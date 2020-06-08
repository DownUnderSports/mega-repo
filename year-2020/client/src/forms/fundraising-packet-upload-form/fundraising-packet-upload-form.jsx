import React from 'react'
import LegalUploadForm from 'forms/legal-upload-form'
import { getMimeType, getFileName } from 'common/js/components/pgp-encryptor'

export default class AdminFundraisingPacketUploadForm extends LegalUploadForm {
  getAction         = () => Promise.resolve()

  action            = () => `/admin/users/${this.props.dus_id}/fundraising_packet`

  endpointAttribute = () => 'fundraising_packet'

  directUploadsPath = () => `/rails/active_storage/direct_uploads/fundraising_packet/${this.props.dus_id}`

  renderStatusText = () => this.state.status || 'Unknown'

  setFile = async (ev) => {
    const io = ev.target.files[0]
    this.setState({ submitting: true }, async () => {
      try {
        const mimeType = await getMimeType(io, false),
              fileName = getFileName(io.name, mimeType, this.fileNameValue(io.name))

        if(/^application\/zip$/.test(mimeType) && /\.zip/.test(fileName)) {
          const file = new File( [ io.slice(0, io.size, mimeType) ], fileName, { type: mimeType } )

          this.setState({ file, submitting: false })
        } else {
          throw new Error("Invalid File Type, Zip Archives Only")
        }
      } catch(err) {
        this.onError(err)
      }
    })
  }

  fileInputText = () =>
    (this.state.file && this.state.file.name) || 'Select File (Zip)'

  renderFile = () =>
    <a className="btn btn-block btn-info" href={this.state.link}>Download Packet</a>

  renderFileInput = (ready) =>
    <input
      type="file"
      id="upload-file"
      name="upload[file]"
      className="form-control-file"
      placeholder='Select File (Zip)'
      accept="application/zip"
      onChange={this.setFile}
      required={!this.state.file}
      disabled={!ready}
    />
}
