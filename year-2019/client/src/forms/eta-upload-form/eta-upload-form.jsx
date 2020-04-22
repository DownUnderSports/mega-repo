import InsuranceUploadForm from 'forms/insurance-upload-form'

export default class ETAUploadForm extends InsuranceUploadForm {
  action            = () => `/admin/users/${this.props.dus_id}/eta_proofs`

  endpointAttribute = () => 'eta_proofs'

  directUploadsPath = () => `/rails/active_storage/direct_uploads/eta_proofs/${this.props.dus_id}`
}
