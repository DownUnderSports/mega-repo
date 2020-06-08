import React from 'react';
import Component from 'common/js/components/component'
import CalendarField from 'common/js/forms/components/calendar-field'
import FileDownload from 'common/js/components/file-download'
import LookupTable from 'common/js/components/lookup-table'
import AssignmentsUploadForm from 'forms/assignments-upload-form'
import AssignmentsReassignForm from 'forms/assignments-reassign-form'

const assignmentsUrl = '/admin/assignments/travelers',
      headers = [
        'assigned_to',
        'locked',
        'visited',
        'dus_id',
        'name',
        'team_name',
        'time_zone',
        // 'cmp_ct',
        'msg_ct',
        'pre_join_msg_ct',
        'post_join_msg_ct',
        'interest_level',
        'interest_id',
        'joined_on',
        'assigned_at',
        // 'last_cmp_at',
        'last_contact',
        'follow_up_on',
      ],
      aliasFields = {
        assigned_to: 'assigned_to_full_name',
        assigned_at: 'created_at',
        // cmp_ct: 'completed_assignments',
        follow_up_on: 'follow_up_date',
        // last_cmp_at: 'last_completed_at',
        last_contact: 'last_messaged_at',
        msg_ct: 'message_count',
        pre_join_msg_ct: 'pre_signup_message_count',
        post_join_msg_ct: 'post_signup_message_count',
        joined_on: 'joined_at',
        // sport: 'sport_abbr',
        // state: 'state_abbr',
        time_zone: 'tz_offset',
      },
      tooltips = {
        assigned_at: 'Date and time the assignment was created',
        assigned_to: 'Staff the assignment is for',
        // cmp_ct: 'Number of completed assignments',
        follow_up_on: 'Date set for next follow up',
        interest_id: 'Number mapping of interest level (lower = more interested)',
        interest_level: 'Selected interest level',
        // last_cmp_at: 'Last time an assignment was completed for this user',
        last_contact: 'Last time this user was contacted by a staff member',
        locked: "Assignment can't be reassigned",
        msg_ct: 'Total times this user has been contacted since responding',
        name: 'Name of responded athlete',
        pre_join_msg_ct: 'Total times this user was contacted before joining the team',
        post_join_msg_ct: 'Total times this user has been contacted since joining the team',
        joined_on: 'Date and time the user first was registered for the video',
        team_name: 'state and sport of athlete (UT GBB)',
        time_zone: 'UTC offset of athlete main address (-7 == Utah)',
        visited: 'Assignment was marked as visited today',
      },
      colors = [
        {
          className: 'bg-warning-light',
          description: 'Not Contacted'
        },
        {
          className: 'bg-info-light',
          description: 'Assignment Visited Today'
        },
        {
          className: 'bg-dark',
          description: 'Assignment Locked'
        },
      ]

export default class AssignmentsTravelersPage extends Component {
  filterComponent = (h, v, onChange, defaultComponent) => {
    switch (true) {
      // case /_to|_by/.test(h):
      //   return (
      //     <SelectField
      //       name={h}
      //       value={v}
      //       options={this.staff}
      //       onChange={(n, val) => (v !== (val || {}).value) && onChange(h, (val || {}).value)}
      //       autoCompleteKey='label'
      //       valueKey='value'
      //       viewProps={{
      //         className: 'form-control',
      //         autoComplete: 'off',
      //         required: false,
      //       }}
      //       className="form-control text-dark"
      //       skipExtras
      //     />
      //   )
      case /_(at|contact|on)$/.test(h):
        return (
          <div className="row text-dark">
            <div className='col'>
              <CalendarField
                measurable
                closeOnSelect
                skipExtras
                className='form-control'
                name={h}
                type='text'
                pattern={"^[!><=]*(\\d{4}-\\d{2}-\\d{2}|[Nn]*)$"}
                onChange={(e, o) => onChange(h, o.value)}
                value={v}
              />
            </div>
          </div>
        )
      default:
        return defaultComponent(h, v)
    }
  }

  rowClassName(a){
    switch (+a.message_count || 0) {
      case 0:  return 'clickable bg-warning-light'
      default: return `clickable ${a.visited ? 'bg-info-light' : (a.locked ? 'bg-dark text-light' : '')}`
    }
  }

  renderButtons = ({getParams, getRecordCount, reload}) => (
    <div key="renderedButtonsWrapper" className="row mb-3">
      <div key="csvDownloadWrapper" className="col-auto">
        <FileDownload key="unassignedCsvDownload" path={`${assignmentsUrl}.csv`}>
          <span key="csvDownloadButton" className="btn btn-primary clickable btn-info">
            Download Unassigned
          </span>
        </FileDownload>
        <FileDownload key="allCsvDownload" path={`${assignmentsUrl}.xlsx`} emailed>
          <span key="csvDownloadButton" className="ml-3 btn btn-primary clickable btn-info">
            Status Sheet
          </span>
        </FileDownload>
      </div>
      <div key="renderedButtonsSeparator" className="border border-dark mb-3" style={{minHeight: '38px'}}></div>
      <div key="assignmentFormWrapper" className="col">
        <AssignmentsUploadForm key="assignmentUploadForm" url={assignmentsUrl} reload={reload}/>
      </div>
      <div key="reassignmentFormWrapper" className="col">
        <AssignmentsReassignForm key="reassignmentForm" url={`${assignmentsUrl}/reassign`} getRecordCount={getRecordCount} getParams={getParams} reload={reload}/>
      </div>
    </div>

  )

  render() {
    return (
      <div key="assignmentsLookupWrapper" className="Assignments TravelersPage row">
        <div className="col">
          <h3 className="text-center pb-3">Travelers</h3>
        </div>
        <LookupTable
          key="assignmentsLookupTable"
          url={assignmentsUrl}
          headers={headers}
          tooltips={tooltips}
          aliasFields={aliasFields}
          initialSearch={true}
          filterComponent={this.filterComponent}
          rowClassName={this.rowClassName}
          localStorageKey="adminAssignmentsTravelersAssigned"
          resultsKey="assignments"
          idKey="dus_id"
          tabKey="user"
          className="col-12"
          renderButtons={this.renderButtons}
          showUrl="/admin/users"
          colors={colors}
        />
      </div>
    );
  }
}
