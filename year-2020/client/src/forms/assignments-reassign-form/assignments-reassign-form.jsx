import React from 'react'
import Component from 'common/js/components/component'
import { StaffUsers } from 'common/js/contexts/staff-users';
import { DisplayOrLoading } from 'react-component-templates/components';
import StaffUserSelectField from 'common/js/forms/components/staff-user-select-field';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'

export default class AssignmentsReassignForm extends Component {
  static contextType = StaffUsers.Context

  get staff() {
    return this.state.staff || []
  }

  get recordCount() {
    return (this.props.getRecordCount &&  this.props.getRecordCount()) || 0
  }

  get staffName() {
    return (this.context.staffUsersActions.find(this.state.staff_id) || {}).name
  }

  get prefix() {
    return String(this.props.prefix || "")
  }

  constructor(props) {
    super(props)
    this.state = {
      submitting: false,
      submitted: false,
      message: false,
      staff: [],
      staff_id: '',
      errors: '',
    }
  }

  // async componentDidMount() {
  //   console.log(this)
  //   // try {
  //   //   await this.fetchStaffUsers()
  //   // } catch (e) {
  //   //   console.error(e)
  //   // }
  //   //
  //   // this.setState({
  //   //   staff: this.props.staffUsersActions.toArray((s) => ({
  //   //     id: s.id,
  //   //     value: s.id,
  //   //     label: s.name
  //   //   }))
  //   // })
  // }

  // fetchStaffUsers = () => (this.props.staffUsersState.loaded ? Promise.resolve() : this.props.staffUsersActions.getStaffUsers())

  onSubmit = (e) => {
    e.preventDefault();
    if(this.state.staff_id && window.confirm(`\nThis will reassign ${this.recordCount} records to ${this.staffName}.\n\nAre you sure you want to continue?\n`)) {
      this.setState({submitting: true})
      this.handleSubmit()
    }
  }

  handleSubmit = async () => {
    try {
      const [filterParams, sortParams, objToStore] = this.props.getParams()

      console.log(filterParams, sortParams, objToStore)

      const result =  await fetch(`${this.props.url}?reassign=1${filterParams}${sortParams}`, {
      // const result =  await fetch(`${this.props.url}`, {
        method: 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({staff_id: this.state.staff_id})
      }),
      json = await result.json()

      this.setState({submitting: false, submitted: (json.message === 'TEST'), ...json}, this.props.reload)
    } catch(e) {
      console.error(e)
      this.setState({submitting: false, errors: [e.message]})
    }

  }

  render() {
    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        <form
          action={this.props.url}
          autoComplete="off"
          className="row"
          encType="multipart/form-data"
          method='post'
          onSubmit={this.onSubmit}
        >
          <div className="col-md col-lg-6">
            <StaffUserSelectField
              id={`${this.prefix}reassign-staff-id`}
              name='reassign[staff_id]'
              value={this.state.staff_id}
              onChange={(n, val) => val && val.id && (this.state.staff_id !== val.id) && this.setState({staff_id: val.id})}
              autoCompleteKey='label'
              viewProps={{
                className: 'form-control',
                autoComplete: 'off',
                required: false,
              }}
              className="form-control text-dark"
              skipExtras
            />
            {
              this.state.errors ? (
                <div className="alert alert-danger form-group mt-3" role="alert">
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
                this.state.submitted && (
                  <div className="alert alert-success form-group mt-3" role="alert">
                    { this.state.message }
                  </div>
                )
              )
            }
          </div>
          <div className="col-auto">
            <button disabled={!this.state.staff_id} className='btn btn-primary' type="submit">
              Reassign All Filtered
            </button>
          </div>

        </form>

      </DisplayOrLoading>
    )
  }
}
