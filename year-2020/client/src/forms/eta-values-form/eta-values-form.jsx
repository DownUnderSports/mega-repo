import React                from 'react'
import Component            from 'common/js/components/component'
import { TextField }        from 'react-component-templates/form-components';
import { DisplayOrLoading, Link } from 'react-component-templates/components'
import JellyBox             from 'load-awesome-react-components/dist/square/jelly-box'
import dusIdFormat          from 'common/js/helpers/dus-id-format'
import CopyClip             from 'common/js/helpers/copy-clip'
import ETAUploadForm        from 'forms/eta-upload-form'

const etaUrl = '/admin/traveling/passports/:user_id/eta_values',
      fileUrl = `${window.location.protocol}//authorize.${window.location.host.replace('admin.', '').replace(/:(\d)000/, ":$1100")}/admin/users/:user_id/passport/get_file`

export default class ETAValuesForm extends Component {
  constructor(props) {
    super(props)

    this.state = {
      errors: null,
      submitting: false,
      dusId: '',
      eta_values: '',
      link: ''
    }
  }

  onChange = async (ev) => {
    let dusId = ev.currentTarget.value

    await this.setStateAsync({ dusId, eta_values: '', link:'', errors: null })

    if(dusId && ((dusId = dusIdFormat(String(dusId))).length === 7)) {
      await this.setStateAsync({ submitting: true, dusId })
      try {
        const result = await (this._fetchingResource = fetch(etaUrl.replace(':user_id', dusId))),
              retrieved = await result.text()

        await this.setStateAsync({eta_values: retrieved, link: fileUrl.replace(':user_id', dusId), submitting: false})
      } catch(err) {
        try {
          this.setState({errors: (await err.response.json()).errors, submitting: false})
        } catch(e) {
          this.setState({errors: [ err.toString() ], submitting: false})
        }
      }
    }
    return false
  }

  setYesExtra = () => this.setExtra('POST')
  setNoExtra = () => this.setExtra('DELETE')

  setExtra = async (method) => {
    let dusId = this.state.dusId || ''

    if(dusId && ((dusId = dusIdFormat(String(dusId))).length === 7)) {
      await this.setStateAsync({ submitting: true, errors: null })

      try {
        const result = await (this._fetchingResource = fetch(`/admin/users/${dusId}/eta_proofs/extra`, { method }))

        await result.json()

        this.onChange({currentTarget: {value: this.state.dusId}})

      } catch(err) {
        try {
          this.setState({errors: (await err.response.json()).errors, submitting: false})
        } catch(e) {
          this.setState({errors: [ err.toString() ], submitting: false})
        }
      }
    }
    return false
  }

  copyValues = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    CopyClip.unprompted(this.state.eta_values || '')
  }

  render(){
    return (
      <div className="row">
        <div className="col-lg-6">
          <DisplayOrLoading
            display={!this.state.submitting}
            loadingElement={
              <JellyBox className="page-loader" />
            }
          >
            <div className="form-group">
              <TextField
                name='dus_id'
                label="Get ETA Values for DUS ID"
                onChange={this.onChange}
                value={this.state.dusId || ''}
                caretIgnore='-'
                className='form-control'
                autoComplete='off'
                placeholder='AAA-AAA'
                pattern="[a-zA-Z]*"
                looseCasing
              />
            </div>
            {
              this.state.errors ? (
                <div className="alert alert-danger form-group" role="alert">
                  {
                    this.state.errors.map((v, k) => (
                      <div className='row' key={k}>
                        <div className="col">
                          { v }
                        </div>
                      </div>
                    ))
                  }
                </div>
              ) : (
                this.state.eta_values && (
                  <div className="row">
                    <div className="col">
                      <Link
                        to={this.state.link}
                        target="_passport_image"
                        className="btn btn-block btn-warning"
                      >
                        View Image
                      </Link>
                    </div>
                    <div className="col">
                      <button
                        className="btn btn-block btn-info"
                        onClick={this.copyValues}
                      >
                        Copy ETA Values
                      </button>
                    </div>
                  </div>
                )
              )
            }
          </DisplayOrLoading>
        </div>
        <div className="col-lg-6">
          {
            String(this.state.dusId || '').length === 7
            && (
              this.state.eta_values
              || (
                this.state.errors
                && /not ready/i.test(String(this.state.errors[0] || ''))
              )
            )
            && <ETAUploadForm dus_id={this.state.dusId} key={this.state.dusId}>
              <div className="row mt-3">
                <div className="col">
                  <button
                    className="btn btn-block btn-danger"
                    onClick={this.setYesExtra}
                  >
                    Mark Extra Processing
                  </button>
                </div>
                <div className="col">
                  <button
                    className="btn btn-block btn-danger"
                    onClick={this.setNoExtra}
                  >
                    Unmark Extra Processing
                  </button>
                </div>
              </div>
            </ETAUploadForm>
          }
        </div>
      </div>
    )
  }

}
