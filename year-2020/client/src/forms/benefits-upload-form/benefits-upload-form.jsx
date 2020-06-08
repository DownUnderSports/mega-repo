import LegalUploadForm from 'forms/legal-upload-form'

export default class AdminBenefitsUploadForm extends LegalUploadForm {
  getAction         = () => Promise.resolve()

  action            = () => `/admin/users/${this.props.dus_id}/assignment_of_benefits`

  endpointAttribute = () => 'assignment_of_benefits'

  directUploadsPath = () => `/rails/active_storage/direct_uploads/assignment_of_benefits/${this.props.dus_id}`

  signingLink       = () => 'https://signnow.com/s/pKmXDrmr?form=true'
}
