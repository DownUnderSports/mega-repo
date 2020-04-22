import LegalUploadForm from 'forms/legal-upload-form'

export default class AdminIncentiveDeadlinesUploadForm extends LegalUploadForm {
  getAction         = () => Promise.resolve()

  action            = () => `/admin/users/${this.props.dus_id}/incentive_deadlines`

  endpointAttribute = () => 'incentive_deadlines'

  directUploadsPath = () => `/rails/active_storage/direct_uploads/incentive_deadlines/${this.props.dus_id}`

  renderStatusText = () => this.state.status || 'Unknown'
}
