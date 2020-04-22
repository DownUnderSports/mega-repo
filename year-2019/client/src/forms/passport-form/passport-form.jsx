import React from 'react'
import { Link } from 'react-component-templates/components';
import PassportForm from 'common/js/forms/passport-form'
import AuthStatus from 'common/js/helpers/auth-status'
import MethodLink from 'common/js/forms/components/method-link'

export default class AdminPassportForm extends PassportForm {

  action              = () => `/admin/users/${this.props.dusId}/passport`
  directUploadsPath   = () => `/rails/active_storage/direct_uploads/passport/${this.props.dusId}`
  directUploadHeaders = () => ({
    ...AuthStatus.headerHash,
    'X-CSRF-Token': '',
    'Content-Type': 'application/json;charset=UTF-8',
  })

  showForm         = () => !!this.state.showForm
  showInfoFields   = () => !!(this.state.needs_image || this.state.showInfoFields)
  onShowInfoFields = () => this.setState({showInfoFields: true})
  onComplete       = () => this.setState({completed: false}, this.getPassport)
  onCancel         = () => this.setState({showForm: false, showInfoFields: false}, this.getPassport)

  submitButtons = (props) =>
    <div className="row">
      <div className="col">
        <button type="button" className='btn btn-danger float-left' onClick={this.onCancel}>
          Cancel
        </button>
      </div>
      <div className="col-auto">
        <button type="submit" className='btn btn-primary float-right' {...(props || {})}>
          Submit Passport
        </button>
      </div>
    </div>

  errorsSection = () =>
    <>
      { this.renderErrors() }
      <button
        type="button"
        className="btn btn-block btn-danger mb-3"
        onClick={this.onShowInfoFields}
      >
        Edit Passport Fields
      </button>
    </>

  imageSection = () =>
    this.state.needs_image ? this.encryptFileField() : (
      <>
        <Link
          to={this.state.link}
          target="_passport_image"
          className="btn btn-block btn-warning mb-3"
        >
          View Image
        </Link>
        {
          this.state.can_delete && (
            <MethodLink
              url={this.action()}
              method="DELETE"
              confirmationMessage={"Are you sure you want to delete this image?\nThis cannot be undone"}
              onSuccess={this.onComplete}
              className="btn btn-danger my-3"
            >
              Delete Image
            </MethodLink>
          )
        }
      </>

    )
}
