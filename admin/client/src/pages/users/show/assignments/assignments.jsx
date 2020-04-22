import React from 'react';
import Component from 'common/js/components/component/async'
import CalendarField from 'common/js/forms/components/calendar-field'
import { StaffUsers } from 'common/js/contexts/staff-users';
import StaffUserSelectField from 'common/js/forms/components/staff-user-select-field';
import { DisplayOrLoading } from 'react-component-templates/components';
import { usersUrl } from 'components/user-info';

class UsersShowAssignmentsPage extends Component {
  get staff() {
    return this.state.staff || []
  }

  constructor(props) {
    super(props)
    this.state = { staff: [], assignments: [], followUp: null, showAll: false }
  }

  afterMount = async () => {
    try {
      await this.fetchStaffUsers()
    } catch (e) {
      console.error(e)
    }

    this.setState({
      staff: this.props.staffUsersActions.toArray((s) => ({
        id: s.id,
        value: s.id,
        label: s.name
      }))
    })

    if(!this.props.user || !this.props.user.dus_id) return await this.getUser()
    else return [
      await this.getAssignments(),
    ]
  }

  fetchStaffUsers = () => (this.props.staffUsersState.loaded ? Promise.resolve() : this.props.staffUsersActions.getStaffUsers())


  getUser = async () => {
    if(!this.props.id) return false
    try {
      const result = await fetch(usersUrl.replace(':id', this.props.id)),
            retrieved = await result.json()

      if(this.props.afterFetch) this.props.afterFetch({user: retrieved})
      if(this._isMounted) return await this.getAssignments()
    } catch(e) {
      console.error(e)
    }
    return true
  }

  getAssignments = async () => {
    if(this._isMounted) {
      await this.setStateAsync({ loading: true })
      try {
        const result = await fetch(usersUrl.replace(':id', `${this.props.id}/assignments`)),
              json = await result.json();

        if(this._isMounted) {
          return await this.setStateAsync({assignments: json.assignments || [], loading: false})
        }
      } catch(e) {
        console.error(e)
        if(this._isMounted){
          await this.setStateAsync({assignments: [], offers: [], loading: false})
        }
      }
    }
    return true
  }

  toggleFullList = async () => await this.setStateAsync({ showAll: !this.state.showAll })

  markVisited = async (id) => await this.updateAssignment(id, { visited: true })

  markNotVisited = async (id) => await this.updateAssignment(id, { visited: false })

  markLocked = async (id) => await this.updateAssignment(id, { locked: true })

  markUnlocked = async (id) => await this.updateAssignment(id, { locked: false })

  markCompleted = async (id) => window.confirm('Are you sure you are completely done with this person?') &&
    await this.updateAssignment(id, { completed: true })

  markIncomplete = async (id) => await this.updateAssignment(id, { completed: false })

  setFollowUp = async (date) => await this.updateAssignment(this.state.followUp, { follow_up_date: date })

  updateAssignment = async (id, params) => {
    try {
      await this.setStateAsync({ loading: true, followUp: null, reassigning: null })
      await fetch(usersUrl.replace(':id', `${this.props.id}/assignments/${id}`), {
        method: 'PATCH',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({
          assignment: params
        })
      })
    } catch(e) {
    }

    await this.getAssignments()
  }

  afterFetch = (args) => this.props.afterFetch(args)

  render() {
    const { match: { params: { id } } } = this.props || {},
          { showAll, assignments } = this.state || {}

    return (
      <div key={id} className="Assignments">
        <section className='assignment-pages-wrapper' id='assignment-pages-wrapper'>
          <header className='mb-3'>
            <h2 className="text-center">
              Assignments
              <button className='btn btn-secondary mx-1 float-right' onClick={this.toggleFullList}>
                { showAll ? 'Hide' : 'Show' } Completed
              </button>
            </h2>
          </header>
          <DisplayOrLoading display={!this.state.loading} >
            <table className='table table-striped table-bordered'>
              <thead>
                <tr>
                  <th></th>
                  <th>
                    Assigned To
                  </th>
                  <th>
                    Assigned By
                  </th>
                  <th>
                    Reason
                  </th>
                  <th>
                    Assigned At
                  </th>
                  {
                    !!showAll
                    && (
                      <th>
                        Completed At
                      </th>
                    )
                  }
                  <th>
                    Follow Up With On
                  </th>
                  <th>
                    Locked?
                  </th>
                  <th>
                  </th>
                </tr>
              </thead>
              <tbody>
                {
                  (assignments || []).map(
                    (a, i) =>
                      !!(showAll || !a.completed)
                      && (
                        <tr className={a.completed ? 'bg-success' : ''} key={i}>
                          <td>
                            <i className={`material-icons text-${a.visited || a.completed ? 'success' : 'danger'}`}>
                              {a.visited || a.completed ? 'done' : 'error_outline'}
                            </i>
                          </td>
                          <td>
                            {
                              this.state.reassigning ? (
                                <StaffUserSelectField
                                  name='assigned_to'
                                  value={a.assigned_to_id}
                                  onChange={(n, val) => val && val.id && (a.assigned_to_id !== val.id) && this.updateAssignment(a.id, {assigned_to_id: val.id})}
                                  autoCompleteKey='label'
                                  viewProps={{
                                    className: 'form-control',
                                    autoComplete: 'off',
                                    required: false,
                                  }}
                                  className="form-control text-dark"
                                  skipExtras
                                />
                              ) : a.assigned_to
                            }
                          </td>
                          <td>
                            {a.assigned_by}
                          </td>
                          <td>
                            {a.reason}
                          </td>
                          <td>
                            {a.assigned_at}
                          </td>
                          {
                            !!showAll
                            && (
                              <td>
                                {a.completed && a.completed_at}
                              </td>
                            )
                          }
                          <td>
                            {a.follow_up_date}
                          </td>
                          <td>
                            {a.locked ? 'Yes' : 'No'}
                          </td>
                          <td>
                            {
                              a.visited ? (
                                <button className='btn btn-warning m-1' onClick={() => this.markNotVisited(a.id)}>
                                  Mark Not Visited
                                </button>
                              ) : (
                                <button className='btn btn-success m-1' onClick={() => this.markVisited(a.id)}>
                                  Mark Visited
                                </button>
                              )
                            }
                            {
                              a.locked ? (
                                <button className='btn btn-warning m-1' onClick={() => this.markUnlocked(a.id)}>
                                  Unlock
                                </button>
                              ) : (
                                <button className='btn btn-warning m-1' onClick={() => this.markLocked(a.id)}>
                                  Lock
                                </button>
                              )
                            }
                            {
                              this.state.followUp ? (
                                <span className="row">
                                  <span className="col-12">
                                    <div className="py-3 border-top border-bottom border-dark" style={{borderWidth: "2px"}}>
                                      <div className="d-none d-xl-block">
                                        <CalendarField
                                          noModal
                                          noText
                                          className="form-control"
                                          skipExtras
                                          name="follow_up"
                                          type='text'
                                          pattern={"\\d{4}-\\d{2}-\\d{2}"}
                                          onChange={(e, o) => this.updateAssignment(a.id, {follow_up_date: o.value})}
                                          value={a.follow_up_date}
                                          size={50}
                                        />
                                      </div>
                                      <div className="d-xl-none">
                                        <CalendarField
                                          noForm
                                          placeholder="No Follow Up Set"
                                          className="form-control"
                                          skipExtras
                                          name="follow_up"
                                          type='text'
                                          pattern={"\\d{4}-\\d{2}-\\d{2}"}
                                          onChange={(e, o) => this.updateAssignment(a.id, {follow_up_date: o.value})}
                                          value={a.follow_up_date}
                                          size={50}
                                        />
                                      </div>
                                      <div className="row mt-1 mt-xl-5">
                                        <div className="col">
                                          <button className='btn btn-block btn-warning' onClick={() => this.updateAssignment(a.id, {follow_up_date: null})}>
                                            Clear
                                          </button>
                                        </div>
                                        <div className="col">
                                          <button className='btn btn-block btn-danger' onClick={() => this.setState({followUp: null})}>
                                            Cancel
                                          </button>
                                        </div>
                                      </div>
                                    </div>
                                  </span>
                                </span>
                              ) : (
                                <button className='btn btn-primary m-1' onClick={() => this.setState({followUp: a.id, reassigning: null})}>
                                  Set Follow Up
                                </button>
                              )
                            }
                            {
                              this.state.reassigning ? (
                                <button className='btn btn-primary m-1' onClick={() => this.setState({followUp: null, reassigning: null})}>
                                  Cancel
                                </button>
                              ) : (
                                <button className='btn btn-primary m-1' onClick={() => this.setState({reassigning: a.id, followUp: null})}>
                                  Reassign
                                </button>
                              )
                            }
                            {
                              (a.reason !== 'Respond') && (
                                a.completed ? (
                                  <button className='btn btn-danger bg-danger-light m-1' onClick={() => this.markIncomplete(a.id)}>
                                    Mark Not Complete
                                  </button>
                                ) : (
                                  <button className='btn btn-danger m-1' onClick={() => this.markCompleted(a.id)}>
                                    Mark Complete
                                  </button>
                                )
                              )
                            }
                          </td>
                        </tr>
                      )
                  )
                }
              </tbody>
            </table>
          </DisplayOrLoading>
        </section>
      </div>
    );
  }
}

export default StaffUsers.Decorator(UsersShowAssignmentsPage)
