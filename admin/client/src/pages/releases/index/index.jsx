import React from 'react';
import Component from 'common/js/components/component'
import { CardSection, DisplayOrLoading, Link } from 'react-component-templates/components'
import { TextField } from 'react-component-templates/form-components';
import FileDownload from 'common/js/components/file-download'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { Objected } from 'react-component-templates/helpers';
import { quickSort, defaultComparator } from 'common/js/helpers/quick-sort'

function quickCompare(a, b) {
  let ad = (a.additional_data || {}).dus_id || "",
      bd = (b.additional_data || {}).dus_id || ""
  return defaultComparator(ad, bd)
}

const listGroupClass = { className: 'list-group' }
const emptyObject = {}

export default class ReleasesIndexPage extends Component {
  state = { releases: [], allReleases: [], loading: true, editing: null, errors: [] }

  componentDidMount() {
    super.componentDidMount()
    this.getReleases()
  }

  get lastFetch() {
    return this._lastFetch && (this._lastFetch.getTime() / 1000.0)
  }

  forceReleases = () => this.getReleases(true)

  getReleases = async (force) => {
    await this.setStateAsync({ loading: true, editing: null, editRelease: null, errors: [] })
    const result = await this.fetchReleases(force)
    if(result.epoch) this._lastFetch = new Date(result.epoch)
    if(result.releases) {
      await this.setStateAsync(state => {
        const { releases } = result,
              oldReleases = state.allReleases || []

        for(const release of oldReleases) {
          if(releases.findIndex((rel) => rel.id === release.id) === -1) releases.push(release)
        }

        const allReleases = quickSort(releases, quickCompare)

        return { allReleases, releases: [ ...allReleases ], loading: false }
      })
    }
  }

  fetchReleases = (force) => this.fetchResource(`/admin/releases.json?force=${!!force ? 1 : 0}&from_time=${this.lastFetch || 0}`, { timeout: 5000 })

  setEditing = (ev) => {
    const id = ev.currentTarget.getAttribute("data-id")
    if(id === "new") this.setState({ editing: "new", editRelease: { additional_data: {} }})
    else {
      for(const release of this.state.releases) {
        if(release.id === +id) {
          this.setState({ editing: +id, editRelease: Objected.deepClone(release) })
          break;
        }
      }
    }
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
      const { editing, editRelease: { dus_id, is_signed, allow_contact, notes, net_refundable }, selectedFile } = this.state,
            isCreate = (editing === "new"),
            body = new FormData()

      if(isCreate && !dus_id) throw new Error("DUS ID Required")

      body.append("release[is_signed]", is_signed ? 1 : 0)
      body.append("release[allow_contact]", allow_contact ? 1 : 0)
      body.append("release[notes]", notes || "")
      body.append("release[net_refundable]", (net_refundable && net_refundable.decimal) || "")

      if(selectedFile) {
        body.append("release[release_form]", selectedFile)
      }

      const result = await fetch(isCreate ? `/admin/releases/?id=${dus_id}` : `/admin/releases/${editing}`, {
        method: isCreate ? "POST" : "PATCH",
        // headers: { "Content-Type": "multipart/form-data" },
        body
      });

      await result.json()

      await this.getReleases()

    } catch(err) {
      try {
        this.setState({errors: (await err.response.json()).errors, loading: false})
      } catch(e) {
        this.setState({errors: [ err.message ], loading: false})
      }
    }
  }

  forceRecalculate = async () => {
    await this.setStateAsync({ loading: true, errors: [] })

    try{
      const result = await fetch("/admin/releases", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ recalculate_all: 1 })
      });

      await result.json()

      this._lastFetch = null

      await this.getReleases()

    } catch(err) {
      try {
        this.setState({errors: (await err.response.json()).errors, loading: false})
      } catch(e) {
        this.setState({errors: [ err.message ], loading: false})
      }
    }
  }

  filter = (val) => {
    this.setState(state => {
      if(!val) return { releases: [ ...state.allReleases ] }

      const { allReleases } = state

      return {
        releases: allReleases.filter((r) => {
          const { dus_id, print_names } = r.additional_data || {}
          if(dus_id && dus_id.toLowerCase().replace(/[^a-z]/g, "").includes(val.toLowerCase().replace(/[^a-z]/g, ""))) return true
          if(print_names && print_names.toLowerCase().includes(val.toLowerCase())) return true
          return false
        })
      }
    })
  }

  renderEditing = () => {
    const { loading, editing, editRelease, selectedFile, errors } = this.state

    return (
      <CardSection
        key={editing}
        className='mb-3'
        label={
          editRelease.id
          ? (
              <span className="text-center">
                <Link to={`/admin/users/${editRelease.additional_data.dus_id}`} target="dus_user">
                  { editRelease.additional_data.print_names } ({ editRelease.additional_data.dus_id })
                </Link>
                &nbsp;-&nbsp;
                <Link className="btn btn-info" to={`/admin/users/${editRelease.additional_data.dus_id}/statement`} target="dus_statements">
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
            )
          : (
              <span>
                <button className="btn btn-danger" onClick={this.cancelEditing}>
                  Cancel
                </button>
                &nbsp;-&nbsp;
                <button className="btn btn-primary" onClick={this.submitEditing}>
                  Submit
                </button>
              </span>
            )
        }
        contentProps={listGroupClass}
      >
        <div className="list-group-item">
          <div className="row">
            {
              !!editRelease.id
                ? (
                    <div className="col">
                      <table className="table">
                        <tbody>
                          <tr>
                            <th>
                              Age
                            </th>
                            <td colSpan="2">
                              { editRelease.additional_data.age }
                            </td>
                          </tr>
                          <tr>
                            <th>
                              Birth Date
                            </th>
                            <td colSpan="2">
                              { editRelease.additional_data.birth_date }
                            </td>
                          </tr>
                          <tr>
                            <th>
                              Total Paid In
                            </th>
                            <td colSpan="2">
                              { (editRelease.additional_data.total_payments || emptyObject).str_pretty }
                            </td>
                          </tr>
                          <tr>
                            <th>
                              Deposit Amount
                            </th>
                            <td colSpan="2">
                              { (editRelease.additional_data.deposit_amount || emptyObject).str_pretty }
                            </td>
                          </tr>
                          <tr>
                            <th>
                              Insurance Paid
                            </th>
                            <td colSpan="2">
                              { (editRelease.additional_data.insurance_paid || emptyObject).str_pretty }
                            </td>
                          </tr>
                          <tr>
                            <th>
                              Dreamtime Paid
                            </th>
                            <td colSpan="2">
                              { (editRelease.additional_data.dreamtime_paid || emptyObject).str_pretty }
                            </td>
                          </tr>
                          <tr>
                            <th>
                              Net Refundable (System Generated)
                            </th>
                            <td colSpan="2">
                              { (editRelease.additional_data.refundable_amount || emptyObject).str_pretty }
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  )
                : (
                    <div className="col">
                      <div className="form-group">
                        <label>DUS ID:</label>
                        <input
                          name={`${editing}_dus_id`}
                          className="form-control"
                          value={editRelease.dus_id || ''}
                          onChange={this.setDusId}
                        />
                      </div>
                    </div>
                  )
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
    const { releases, loading, editing } = this.state
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
            <button className="btn btn-block btn-warning mb-3" onClick={this.forceReleases}>
              Refresh List
            </button>
          </div>
          <div className="col">
            <button className="btn btn-block btn-danger mb-3" onClick={this.forceRecalculate}>
              Recalculate All Payment Data
            </button>
          </div>
          <div className="col">
            <button className="btn btn-block btn-success mb-3" onClick={this.setEditing} data-id="new">
              Add New Release
            </button>
          </div>
          <div className="col-12">
            <p className="text-center text-danger">
              *The buttons above will also reset any open form*
            </p>
            <hr/>
            {
              !editing
              && (
                <TextField
                  name={`search[mailings]`}
                  onChange={(e) => this.filter(e.target.value)}
                  className='form-control mb-3'
                  autoComplete='off'
                  placeholder="filter results by name or DUS ID (not case sensitive)"
                  skipExtras
                />
              )
            }
          </div>
        </div>
        {
          editing
            ? this.renderEditing()
            : releases.map(release => (
                <CardSection
                  key={release.id}
                  className='mb-3'
                  label={<span className="text-center">
                    <Link to={`/admin/users/${release.additional_data.dus_id}`} target="dus_user">
                      { release.additional_data.print_names } ({ release.additional_data.dus_id })
                    </Link>
                    &nbsp;-&nbsp;
                    <Link className="btn btn-info" to={`/admin/users/${release.additional_data.dus_id}/statement`} target="dus_statements">
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
                                { release.additional_data.age }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Birth Date
                              </th>
                              <td colSpan="2">
                                { release.additional_data.birth_date }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Total Paid In
                              </th>
                              <td colSpan="2">
                                { (release.additional_data.total_payments || emptyObject).str_pretty }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Deposit Amount
                              </th>
                              <td colSpan="2">
                                { (release.additional_data.deposit_amount || emptyObject).str_pretty }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Insurance Paid
                              </th>
                              <td colSpan="2">
                                { (release.additional_data.insurance_paid || emptyObject).str_pretty }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Dreamtime Paid
                              </th>
                              <td colSpan="2">
                                { (release.additional_data.dreamtime_paid || emptyObject).str_pretty }
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Net Refundable (System Generated)
                              </th>
                              <td colSpan="2">
                                { (release.additional_data.refundable_amount || emptyObject).str_pretty }
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
                                { release.is_signed ? "Y" : "N" }
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
                                { release.net_refundable ? release.net_refundable.str_pretty : `SYSTEM (${(release.additional_data.refundable_amount || emptyObject).str_pretty})` }
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
              ))
        }
      </DisplayOrLoading>
    )
  }
}
