import React from 'react'
import EncryptedFile from 'common/js/components/encrypted-file'
import { Objected } from 'react-component-templates/helpers'
import { DisplayOrLoading } from 'react-component-templates/components';
import { TextField, InlineRadioField } from 'react-component-templates/form-components';
import AuthoritySelectField from 'common/js/forms/components/authority-select-field';
import NationalitySelectField from 'common/js/forms/components/nationality-select-field';
import CalendarField from 'common/js/forms/components/calendar-field';
import { DirectUploadProvider } from 'react-activestorage-provider'
import { Nationality } from 'common/js/contexts/nationality';
import VisaForm, { visaBaseState } from 'common/js/forms/visa-form'
import ppSample from 'common/assets/images/passport.jpg'

const baseState = {
  ...visaBaseState,
  has_questions_answered: false,
  upload: {},
  type: '',
  code: '',
  number: '',
  surname: '',
  given_names: '',
  nationality: '',
  birth_date: '',
  birthplace: '',
  country_of_birth: '',
  sex: '',
  issued_date: '',
  authority: '',
  expiration_date: '',
}

export default class PassportForm extends VisaForm {
  static contextType = Nationality.Context

  get baseState() {
    return baseState
  }

  state = { ...Objected.deepClone(this.baseState), showSampleImg: false, loading: true, showForm: false, showInfoFields: false }

  action = () => `/api/departure_checklists/${this.props.dusId}/passport`
  directUploadsPath = () => `/api/direct_uploads/${this.props.dusId}/passport`
  getBaseState = () => Objected.filterKeys(Objected.deepClone(this.baseState), ['upload'])
  getFallbackBaseState = () => Objected.deepClone(this.baseState)
  getPassport = () => this.getDataFromServer()

  onAnswerChange = (v) => this.onChange('has_questions_answered', v)
  onFileSelect = (_, upload) => this.setState({ upload })
  onSexChange = (v) => this.onChange('sex', v)
  onAuthorityChange = (_, { value }) => this.onChange('authority', value)
  onCountryChange = (_, { value }) => this.onChange('country_of_birth', value)
  onCountryBlur = (_, { label }) => this.onChange('country_of_birth', label)
  classifyAuthority = () => this.state.authority && this.setState({ authority: this.state.authority.split(/\s+/).map((v) => /^(the|of)$/.test(v) ? v : String(v).capitalize()) })

  showForm = () => true
  showInfoFields = () => !!this.state.needs_image
  toggleForm = async () => {
    this.setState({ loading: !!this.state.showForm, showForm: !this.state.showForm }, async () => {
      this.showForm() && await this.getDataFromServer()
    })
  }

  toggleSampleImg = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.setState({ showSampleImg: !this.state.showSampleImg })
  }

  setDataValue = (data, name, value) => {
    if(Array.isArray(value)) {
      for (let i = 0; i < value.length; i++) {
        this.setDataValue(data, `${name}[]`, value[i])
      }
    } else if(Object.isObject(value)) {
      for (let i in value) {
        this.setDataValue(data, `${name}[${i}]`, value[i])
      }
    } else {
      data.append(name, value)
    }
  }

  onSubmit = (ev) => {
    try {
      ev.preventDefault()
      ev.stopPropagation()
    } catch(_) {}

    this.setState({ loading: true }, async () => {
      try {
        const { changed = false, changes: state } = Objected.existingOnly(Objected.filterKeys(this._baseValues || this.baseState, ['upload']), this.state),
              upload    = { ...(this.state.upload || {}) },
              signedIds = [ ...(this.state.signedIds || []) ],
              options   = { method: 'POST' }

        if(state.country_of_birth && !Number.isNaN(Number(state.country_of_birth))) {
          state.country_of_birth = (this.context.nationalityActions.find(state.country_of_birth) || {}).label
        } else {
          state.country_of_birth = state.country_of_birth || ''
        }

        if(this.verifying) {
          options.method = 'PATCH'
          options.headers = { "Content-Type": "application/json; charset=utf-8" }
          options.body = JSON.stringify({ passport: state })
        } else {
          if(!changed && !upload.value) throw new Error("Nothing to Submit")

          if(state.has_questions_answered) this.validateVisa(state)

          if(upload.value && !signedIds.length) {
            const data = new FormData()
            data.set('upload[io]', upload.value)
            data.set('upload[filename]', upload.fileName)
            data.set('upload[content_type]', upload.mimeType)
            data.set('upload[identify]', false)
            for (let k in state) {
              this.setDataValue(data, `passport[${k}]`, state[k])
            }

            options.body = data
          } else {
            options.headers = { "Content-Type": "application/json; charset=utf-8" }
            options.body = JSON.stringify({ passport: state, signed_upload: signedIds.length ? { image: signedIds[0] } : null })
          }
        }

        const result = await fetch(this.action(), options),
                json = await result.json()

        if(json.message === 'ok' || this.verifying) {
          this._baseValues = null
          this.setState({
            ...this.baseState,
            errors: (json.message === 'ok') ? null : json.errors,
            completed: true,
            showForm: false,
            showInfoFields: false,
            loading: false
          }, () => setTimeout(this.onComplete, 2000))
        } else {
          this.setState({ loading: false, errors: [ json.message ] })
        }
      } catch(err) {
        console.log(err)
        try {
          this.setState({errors: (await err.response.json()).errors, loading: false})
        } catch(e) {
          this.setState({errors: [ err.message ], loading: false})
        }
      }
    })
  }

  imageSection = () =>
    !!this.state.needs_image && this.encryptFileField()

  backupSection = () =>
    <div className="row">
      <div className="col-12">
        <h3 className={`text-center mb-3 text-${ !!this.state.needs_image ? 'danger' : 'success' }`}>
          { !!this.state.needs_image ? "Passport Image Missing" : "Passport Image Submitted" }
        </h3>
        <button className="btn btn-block btn-primary" onClick={this.toggleForm}>
          Edit/Submit Passport
        </button>
      </div>
    </div>

  completedMessage = () =>
    <p>
      You will be redirected to the checklist page shortly...
    </p>

  onDirectUploadError = async e => {
    let errors
    try {
      errors = await e.response.json()
    } catch(_) {
      errors = []
    }
    this.setState({
      errors: [e.message, ...(errors || [])]
    })
  }

  onDirectUploadSuccess = async signedIds => this.setState({ signedIds }, this.onSubmit)
  directUploadHeaders = () => undefined

  directUpload = () =>
    <DirectUploadProvider
      directUploadsPath={this.directUploadsPath()}
      headers={this.directUploadHeaders()}
      onSuccess={this.onDirectUploadSuccess}
      render={({ handleUpload, ready }) => {
        return (
          <div className="row">
            <div className="col-12">
              {
                this.submitButtons({
                  disabled: (!ready || !this.state.upload || !this.state.upload.value),
                  onClick: ev => {
                    ev.preventDefault()
                    ev.stopPropagation()
                    this.setState({ loading: true }, async () => {
                      try {
                        await handleUpload([this.state.upload.value])
                      } catch (err) {
                        this.onDirectUploadError(err)
                      }
                    })
                  }
                })
              }
            </div>
          </div>
        )
      }}
    />

  /* eslint-disable jsx-a11y/img-redundant-alt */
  encryptFileField = () =>
    <div className="row form-group">
      <div className="col-12">
        <p key="sample-photo-header" className="text-center mt-3">Sample Passport Photo Page</p>
        <div key="sample-photo-wrapper" className="d-flex justify-content-center">
          <img key="sample-photo" src={ppSample} className="img-fluid" alt="sample photo page"/>
        </div>
        <hr/>
        <label htmlFor={`${this.props.dusId}_passport_image_field`}>
          Select Passport File (Image or PDF)
        </label>
        <EncryptedFile
          id={`${this.props.dusId}_passport_image_field`}
          fileName={`${(this.props.dusId || 'INVALID').replace('-', '')}-passport`}
          onChange={this.onFileSelect}
          {...this.state.upload}
        />
        <hr/>
      </div>
    </div>
  /* eslint-enable jsx-a11y/img-redundant-alt */

  submitSection = () =>
    this.state.needs_image
      ? this.directUpload()
      : this.submitButtons()

  submitText = () => 'Submit Passport'

  passportInfoSection = () =>
    this.showInfoFields() ? this.passportFields() : this.errorsSection()

  passportFields = () =>
    <>
      <div className="row form-group">
        <div className={`col-12 text-center ${this.state.errors && this.state.errors.length && 'text-danger'}`}>
          <h3>
            Please fill out the following <strong>exactly</strong> as shown on the passport
          </h3>
          <h6 className="text-muted"><i>(e.g. John is not the same as JOHN)</i></h6>
        </div>
      </div>
      { this.renderErrors() }
      <div className="row">
        <div className="col mb-3">
          <TextField
            className="form-control"
            name="passport[type]"
            label='Type'
            placeholder='(P)'
            value={this.state.type || ''}
            onChange={this.onTextChange}
            onBlur={this.onTextBlur}
            autoComplete={this.autoComplete}
            required
          />
        </div>
        <div className="col mb-3">
          <TextField
            className="form-control"
            name="passport[code]"
            label='Code'
            placeholder='(USA)'
            value={this.state.code || ''}
            onChange={this.onTextChange}
            onBlur={this.onTextBlur}
            autoComplete={this.autoComplete}
            required
          />
        </div>
        <div className="col mb-3">
          <TextField
            className="form-control"
            name="passport[number]"
            label='Passport No'
            placeholder='(340020013)'
            value={this.state.number || ''}
            onChange={this.onTextChange}
            onBlur={this.onTextBlur}
            autoComplete={this.autoComplete}
            required
          />
        </div>
      </div>
      <div className="row">
        <div className={`${this.props.dividerClassName || 'col-lg'} col-12`}>
          <div className="mb-3">
            <TextField
              className="form-control"
              name="passport[surname]"
              label='Surname'
              placeholder='(TRAVELER)'
              value={this.state.surname || ''}
              onChange={this.onTextChange}
              onBlur={this.onTextBlur}
              autoComplete={this.autoComplete}
              required
            />
          </div>
          <div className="mb-3">
            <TextField
              className="form-control"
              name="passport[given_names]"
              label='Given Names'
              placeholder='(HAPPY)'
              value={this.state.given_names || ''}
              onChange={this.onTextChange}
              onBlur={this.onTextBlur}
              autoComplete={this.autoComplete}
              required
            />
          </div>
          <div className="mb-3">
            <TextField
              className="form-control"
              name="passport[nationality]"
              label='Nationality'
              placeholder='(UNITED STATES OF AMERICA)'
              value={this.state.nationality || ''}
              onChange={this.onTextChange}
              onBlur={this.onTextBlur}
              autoComplete={this.autoComplete}
              required
            />
          </div>
          <div className="mb-3">
            <CalendarField
              autoComplete={this.autoComplete}
              multiText
              required
              closeOnSelect
              allowBlank
              className='form-control'
              name="passport[birth_date]"
              label="Date of birth"
              feedback='The Date the passport holder was born'
              type='text'
              pattern={"^\\d{4}-\\d{2}-\\d{2}$"}
              onChange={(e, o) => this.onChange('birth_date', o.value || '')}
              value={this.state.birth_date || ''}
            />
          </div>
        </div>
        <div className="col"></div>
      </div>
      <div className="row">
        <div className={`${this.props.dividerClassName || 'col-lg'} col-12`}>
          <div className="mb-3">
            <TextField
              className="form-control"
              name="passport[birthplace]"
              label='Place of birth'
              placeholder='(WASHINGTON, D.C., U.S.A.)'
              value={this.state.birthplace || ''}
              onChange={this.onTextChange}
              onBlur={this.onTextBlur}
              autoComplete={this.autoComplete}
              required
            />
          </div>
          {
            (!/U\.?S\.?A\.?\s*|UNITED\s+STATES.+AMERICA$/.test(this.state.birthplace || 'USA')) && (
              <div className="mb-3">
                <NationalitySelectField
                  viewProps={{ className: "form-control" }}
                  name="passport[country_of_birth]"
                  label='Country of Birth'
                  placeholder='Mexico (MEX)'
                  autoCompleteKey='label'
                  value={this.state.country_of_birth || ''}
                  onChange={this.onCountryChange}
                  onBlur={this.onCountryBlur}
                  required
                />
              </div>
            )
          }
        </div>
        <div className="col mb-3">
          <InlineRadioField
            name="passport[sex]"
            label='Sex'
            value={this.state.sex || ''}
            onChange={this.onSexChange}
            required
            options={[
              { value: 'M', label: 'M (Male)' },
              { value: 'F', label: 'F (Female)', },
            ]}
          />
        </div>
      </div>
      <div className="row">
        <div className={`${this.props.dividerClassName || 'col-lg'} col-12 mb-3`}>
          <CalendarField
            autoComplete={this.autoComplete}
            minimum="1927-01-01"
            maximum={new Date()}
            multiText
            required
            closeOnSelect
            allowBlank
            className='form-control'
            name="passport[issued_date]"
            label="Date of issue"
            feedback='The Date the passport was issued_date'
            type='text'
            pattern={"^\\d{4}-\\d{2}-\\d{2}$"}
            onChange={(e, o) => this.onChange('issued_date', o.value)}
            value={this.state.issued_date || ''}
          />
        </div>
        <div className="col mb-3">
          <AuthoritySelectField
            viewProps={{ className: "form-control" }}
            name="passport[authority]"
            label='Authority'
            placeholder='(United States Department of State)'
            value={this.state.authority || ''}
            onChange={this.onAuthorityChange}
            required
          />
        </div>
      </div>
      <div className="row">
        <div className={`${this.props.dividerClassName || 'col-lg'} col-12 mb-3`}>
          <CalendarField
            autoComplete={this.autoComplete}
            minimum={new Date()}
            multiText
            required
            closeOnSelect
            allowBlank
            className='form-control'
            name="passport[expiration_date]"
            label="Date of expiration"
            feedback='The Date the passport will expire'
            type='text'
            pattern={"^\\d{4}-\\d{2}-\\d{2}$"}
            onChange={(e, o) => this.onChange('expiration_date', o.value)}
            value={this.state.expiration_date || ''}
          />
        </div>
        <div className="col"></div>
      </div>
    </>

  visaFields = () =>
    <div className="row">
      <div className="col-12 mb-3">
        <InlineRadioField
          className="mb-3"
          label='Is the passport holder ready to answer visa questions?'
          value={!!this.state.has_questions_answered}
          onChange={this.onAnswerChange}
          autoComplete={this.autoComplete}
          required
          options={[
            { value: true, label: 'Yes' },
            { value: false, label: 'No', },
          ]}
        />
        { this.state.has_questions_answered && this.visaFormFields() }
      </div>
    </div>

  render() {
    return this.state.completed ? (
      <div className="row">
        <div className="col-12">
          <header>
            <h3 className="mt-3 alert alert-success" role="alert">
              Passport Successfully Submitted
            </h3>
          </header>
          { this.props.onComplete && this.completedMessage() }
        </div>
      </div>
    ) : (
      <DisplayOrLoading
        display={!this.state.loading}
      >
        {
          this.props.dusId && (
            this.showForm() ? (
              <form
                action={this.action()}
                onSubmit={this.onSubmit}
                autoComplete={this.autoComplete}
              >

                { this.imageSection() }

                { this.passportInfoSection() }

                { this.visaFields() }

                { this.submitSection() }

              </form>
            ) : (
              this.backupSection()
            )
          )
        }
      </DisplayOrLoading>
    )
  }
}
