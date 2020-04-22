import React from 'react'
import { Link } from 'react-component-templates/components';
import AdminPassportForm from 'forms/passport-form'

export default class VerifyPassportForm extends AdminPassportForm {

  action              = () => `/admin/traveling/passports/${this.props.dusId}.json`

  showForm         = () => true
  showInfoFields   = () => true
  onComplete       = () => this.props.onComplete()
  onCancel         = () => this.props.onComplete()

  errorsSection = () => this.renderErrors()
  visaFields    = () => false

  completedMessage = () => this.state.errors ? this.renderErrors() : (<div></div>)

  imageSection = () =>
    <Link
      to={this.state.link || ''}
      target="_passport_image"
      className="btn btn-block btn-warning mb-3"
    >
      View Image
    </Link>
}
