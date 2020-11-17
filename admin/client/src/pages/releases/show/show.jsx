import React from 'react';
import Component from 'common/js/components/component'
import { CardSection, DisplayOrLoading, Link } from 'react-component-templates/components'
import FileDownload from 'common/js/components/file-download'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { Objected } from 'react-component-templates/helpers';

const listGroupClass = { className: 'list-group' }

export default class ReleaseIndexPage extends Component {
  state = { release: null, loading: true, editing: null, errors: [] }

  componentDidMount() {
    super.componentDidMount()
    this.getRelease()
  }

  forceRelease = () => this.getRelease(true)

  getRelease = async (force) => {
    await this.setStateAsync({ loading: true, editing: null, editRelease: null, errors: [] })
    await this.setStateAsync({ release: await this.fetchRelease(force), loading: false })
  }

  fetchRelease = (force) => this.fetchResource(`/admin/releases.json?force=${!!force ? 1 : 0}`, { timeout: 5000 }, 'release')

  setEditing = (ev) => {
    this.setState({ editing: +id, editRelease: Objected.deepClone(release) })
  }

  toggleReleaseSigned = ev => {
    const value = !this.state.editRelease.is_signed
    this.setState(state => {
      const editRelease = Objected.deepClone(state.editRelease || {})
      editRelease.is_signed = value
      return { editRelease }
    })
  }

  toggleReleaseContact = ev => {
    const value = !this.state.editRelease.allow_contact
    this.setState(state => {
      const editRelease = Objected.deepClone(state.editRelease || {})
      editRelease.allow_contact = value
      return { editRelease }
    })
  }

  setRefundable = ev => {
    const target = ev.currentTarget
    this.setState(state => {
      const editRelease = Objected.deepClone(state.editRelease || {})
      editRelease.net_refundable = editRelease.net_refundable || {}
      editRelease.net_refundable.decimal = target.value
      return { editRelease }
    })
  }

  setFile = ev => this.setState({ selectedFile: ev.currentTarget.files[0] })

  setNotes = ev => {
    const value = ev.currentTarget.value
    console.log(value)
    this.setState(state => {
      const editRelease = Objected.deepClone(state.editRelease || {})
      editRelease.notes = value || ""
      return { editRelease }
    })
  }

  setDusId = ev => {
    const value = ev.currentTarget.value
    console.log(value)
    this.setState(state => {
      const editRelease = Objected.deepClone(state.editRelease || {})
      editRelease.dus_id = value || ""
      return { editRelease }
    })
  }

  cancelEditing = () => this.setState({ editing: false, editRelease: null })

  submitEditing = async () => {
    await this.setStateAsync({ loading: true, errors: [] })

    try{
      const { editing, editRelease: { is_signed, allow_contact, notes, net_refundable }, selectedFile } = this.state,
            body = new FormData()

      body.append("release[is_signed]", is_signed ? 1 : 0)
      body.append("release[allow_contact]", allow_contact ? 1 : 0)
      body.append("release[notes]", notes || "")
      body.append("release[net_refundable]", (net_refundable && net_refundable.decimal) || "")

      if(selectedFile) {
        body.append("release[release_form]", selectedFile)
      }

      const result = await fetch(`/admin/releases/${editing || 0}`, {
        method: "PATCH",
        // headers: { "Content-Type": "multipart/form-data" },
        body
      });

      await result.json()

      await this.getRelease()

    } catch(err) {
      try {
        this.setState({errors: (await err.response.json()).errors, loading: false})
      } catch(e) {
        this.setState({errors: [ err.message ], loading: false})
      }
    }
  }

  renderEditing = () => {
    const { loading, editing, editRelease, selectedFile, errors } = this.state

    return (
      <CardSection
        key={editing}
        className='mb-3'
        label={
          <span className="text-center">
            <Link to={`/admin/users/${editRelease.payment_data.dus_id}`} target="dus_user">
              { editRelease.payment_data.print_names } ({ editRelease.payment_data.dus_id })
            </Link>
            &nbsp;-&nbsp;
            <Link className="btn btn-info" to={`/admin/users/${editRelease.payment_data.dus_id}/statement`} target="dus_statements">
              Statement <i className="material-icons">outbound</i>
            </Link>
            &nbsp;-&nbsp;
            <button className="btn btn-danger" onClick={this.cancelEditing}>
              Cancel
            </button>
            &nbsp;-&nbsp;
            <button className="btn btn-primary" onClick={this.submitEditing}>
              Submit
            </button>
          </span>
        }
        contentProps={listGroupClass}
      >
        <div className="list-group-item">
          <div className="row">
            {
              <div className="col">
                <table className="table">
                  <tbody>
                    <tr>
                      <th>
                        Age
                      </th>
                      <td colSpan="2">
                        { editRelease.payment_data.age }
                      </td>
                    </tr>
                    <tr>
                      <th>
                        Birth Date
                      </th>
                      <td colSpan="2">
                        { editRelease.payment_data.birth_date }
                      </td>
                    </tr>
                    <tr>
                      <th>
                        Total Paid In
                      </th>
                      <td colSpan="2">
                        { editRelease.payment_data.total_payments.str_pretty }
                      </td>
                    </tr>
                    <tr>
                      <th>
                        Deposit Amount
                      </th>
                      <td colSpan="2">
                        { editRelease.payment_data.deposit_amount.str_pretty }
                      </td>
                    </tr>
                    <tr>
                      <th>
                        Insurance Paid
                      </th>
                      <td colSpan="2">
                        { editRelease.payment_data.insurance_paid.str_pretty }
                      </td>
                    </tr>
                    <tr>
                      <th>
                        Dreamtime Paid
                      </th>
                      <td colSpan="2">
                        { editRelease.payment_data.dreamtime_paid.str_pretty }
                      </td>
                    </tr>
                    <tr>
                      <th>
                        Net Refundable (System Generated)
                      </th>
                      <td colSpan="2">
                        { editRelease.payment_data.refundable_amount.str_pretty }
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            }
            <div className="col">
              {
                !!errors
                && !!errors.length
                && errors.map((v, i) => <div key={i} className="text-danger text-center">{ v }</div>)
              }
              <div className="form-group form-check">
                <input
                  type="checkbox"
                  id={`${editing}_is_signed`}
                  className="form-check-input"
                  value="1"
                  name={`release[is_signed]`}
                  onChange={this.toggleReleaseSigned}
                  checked={!!editRelease.is_signed}
                />
                <label htmlFor={`${editing}_is_signed`}>
                  Signed?
                </label>
              </div>
              <div className="form-group form-check">
                <input
                  type="checkbox"
                  id={`${editing}_future`}
                  className="form-check-input"
                  value="1"
                  name={`release[allow_contact]`}
                  onChange={this.toggleReleaseContact}
                  checked={!!editRelease.allow_contact}
                />
                <label htmlFor={`${editing}_future`}>
                  Future Contact?
                </label>
              </div>

              <div className="form-group">
                <label htmlFor={`${editing}_refundable`}>
                  Refundable Amount Override:
                </label>
                <input
                  type="text"
                  id={`${editing}_refundable`}
                  className="form-control"
                  value={editRelease.net_refundable ? editRelease.net_refundable.decimal : ""}
                  name={`release[net_refundable]`}
                  onChange={this.setRefundable}
                />
              </div>
              <div className="form-group">
                <label htmlFor={`${editing}_form`}>
                  Release Form:
                </label>
                <input
                  type="file"
                  accept="application/pdf"
                  id={`${editing}_form`}
                  className="form-control"
                  name={`release[release_form]`}
                  onChange={this.setFile}
                />
                {
                  selectedFile && (
                    <div>
                      SELECTED | File Name: {selectedFile.name} | File Type: {selectedFile.type}
                    </div>
                  )
                }
              </div>
              <div className="form-group">
                <label>Notes:</label>
                <textarea
                  name={`${editing}_notes`}
                  rows="4"
                  className="form-control"
                  value={editRelease.notes || ''}
                  onChange={this.setNotes}
                />
              </div>
            </div>
          </div>
        </div>
      </CardSection>
    )
  }


  render() {
    const { release, loading, editing } = this.state
    return (
      <DisplayOrLoading
        display={!loading}
        message='LOADING...'
        loadingElement={
          <JellyBox className="page-loader" />
        }
      >
        <div className="row">
          <div className="col">
            <button className="btn btn-block btn-warning mb-3" onClick={this.forceRelease}>
              Refresh (will also reset forms)
            </button>
          </div>
        </div>
        {
          editing
            ? this.renderEditing()
            : (
                <CardSection
                  key={release.id}
                  className='mb-3'
                  label={<span className="text-center">
                    <Link to={`/admin/users/${release.payment_data.dus_id}`} target="dus_user">
                      { release.payment_data.print_names } ({ release.payment_data.dus_id })
                    </Link>
                    &nbsp;-&nbsp;
                    <Link className="btn btn-info" to={`/admin/users/${release.payment_data.dus_id}/statement`} target="dus_statements">
                      Statement <i className="material-icons">outbound</i>
                    </Link>
                    &nbsp;-&nbsp;
                    <button className="btn btn-danger" data-id={release.id} onClick={this.setEditing}>
                      Edit
                    </button>
                  </span>}
                  contentProps={listGroupClass}
                >
                  <div className="list-group-item">
                    <div className="row">
                      <div className="col">
                        <table className="table">
                          <tbody>
                            <tr>
                              <th>
                                Age
                              </th>
                              <td colSpan="2">
                                { release.payment_data.age }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Birth Date
                              </th>
                              <td colSpan="2">
                                { release.payment_data.birth_date }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Total Paid In
                              </th>
                              <td colSpan="2">
                                { release.payment_data.total_payments.str_pretty }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Deposit Amount
                              </th>
                              <td colSpan="2">
                                { release.payment_data.deposit_amount.str_pretty }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Insurance Paid
                              </th>
                              <td colSpan="2">
                                { release.payment_data.insurance_paid.str_pretty }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Dreamtime Paid
                              </th>
                              <td colSpan="2">
                                { release.payment_data.dreamtime_paid.str_pretty }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Net Refundable (System Generated)
                              </th>
                              <td colSpan="2">
                                { release.payment_data.refundable_amount.str_pretty }
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </div>
                      <div className="col">
                        <table className="table labeler">
                          <tbody>
                            <tr>
                              <th>
                                Signed?
                              </th>
                              <td colSpan="2">
                                { release.is_is_signed ? "Y" : "N" }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Future Contact?
                              </th>
                              <td colSpan="2">
                                { release.allow_contact ? "Y" : "N" }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Refundable Amount:
                              </th>
                              <td colSpan="2">
                                { release.net_refundable ? release.net_refundable.str_pretty : `SYSTEM (${release.payment_data.refundable_amount.str_pretty})` }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Refund Percentage:
                              </th>
                              <td colSpan="2">
                                { release.percentage_paid.decimal }%
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Release Form:
                              </th>
                              <td colSpan="2">
                                { release.release_form ? <Link to={release.release_form} className="btn btn-info" target="dus_releases">Open</Link> : "Not Submitted" }
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </div>
                  <div className="list-group-item">
                    <label>Notes:</label>
                    <textarea
                      name={`${ release.id }_notes`}
                      rows="4"
                      className="form-control"
                      value={release.notes || ''}
                      readOnly
                    />
                  </div>
                </CardSection>
              )
        }
      </DisplayOrLoading>
    )
  }
}
