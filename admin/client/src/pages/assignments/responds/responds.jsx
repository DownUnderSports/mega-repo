import React from 'react';
import Component from 'common/js/components/component'
import CalendarField from 'common/js/forms/components/calendar-field'
import FileDownload from 'common/js/components/file-download'
import LookupTable from 'common/js/components/lookup-table'
import AssignmentsUploadForm from 'forms/assignments-upload-form'
import AssignmentsReassignForm from 'forms/assignments-reassign-form'

const assignmentsUrl = '/admin/assignments/responds',
      headers = [
        'assigned_to',
        'locked',
        'visited',
        'dus_id',
        'name',
        'team_name',
        'grad',
        'time_zone',
        // 'cmp_ct',
        'msg_ct',
        'pre_mtg_msg_ct',
        'post_mtg_msg_ct',
        'othr_msg_ct',
        'interest_level',
        'interest_id',
        'did_view',
        'did_watch',
        'duration',
        'registered_on',
        'first_viewed',
        'last_viewed',
        'watched_on',
        'responded_at',
        'assigned_at',
        // 'last_cmp_at',
        'last_contact',
        'follow_up_on',
      ],
      aliasFields = {
        assigned_to: 'assigned_to_full_name',
        assigned_at: 'created_at',
        // cmp_ct: 'completed_assignments',
        did_view: 'viewed',
        did_watch: 'watched',
        first_viewed: 'viewed_at',
        follow_up_on: 'follow_up_date',
        // last_cmp_at: 'last_completed_at',
        last_contact: 'last_messaged_at',
        last_viewed: 'last_viewed_at',
        msg_ct: 'message_count',
        othr_msg_ct: 'other_message_count',
        pre_mtg_msg_ct: 'pre_meeting_message_count',
        post_mtg_msg_ct: 'post_meeting_message_count',
        registered_on: 'registered_at',
        sport: 'sport_abbr',
        state: 'state_abbr',
        time_zone: 'tz_offset',
        watched_on: 'watched_at',
      },
      tooltips = {
        assigned_at: 'Date and time the assignment was created',
        assigned_to: 'Staff the assignment is for',
        // cmp_ct: 'Number of completed assignments',
        did_view: 'Whether the video was ever opened and viewed',
        did_watch: 'Whether the video was viewed past the "watched" mark',
        duration: 'Farthest point reached in the invormation video (HH:MM:SS)',
        first_viewed: 'Date and time the information video was opened for the first time',
        follow_up_on: 'Date set for next follow up',
        grad: 'Athlete Year of Grad if known',
        interest_id: 'Number mapping of interest level (lower = more interested)',
        interest_level: 'Selected interest level',
        // last_cmp_at: 'Last time an assignment was completed for this user',
        last_contact: 'Last time this user was contacted by a staff member',
        last_viewed: 'Date and time of the last time they opened the information video',
        locked: "Assignment can't be reassigned",
        marked_watched: 'Date and time of when they first reached the "watched" mark in the information video',
        msg_ct: 'Total times this user has been contacted since responding',
        name: 'Name of responded athlete',
        othr_msg_ct: 'Total times this user has been contacted since responding for "Other" reasons',
        pre_mtg_msg_ct: 'Total times this user has been contacted since responding for "Pre-Meeting" reasons',
        post_mtg_msg_ct: 'Total times this user has been contacted since responding for "Post-Meeting" reasons',
        registered_on: 'Date and time the user first was registered for the video',
        responded_at: 'Date and time the user first responded at',
        team_name: 'state and sport of athlete (UT GBB)',
        time_zone: 'UTC offset of athlete main address (-7 == Utah)',
        viewed: 'Whether or not they have ever viewed the information video',
        visited: 'Assignment was marked as visited today',
        watched: 'Whether or not they reached the "watched" mark',
        watched_on: 'Date and time the information video was watched past the "watched" mark',
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

export default class AssignmentsRespondsPage extends Component {
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
      case /_(at|contact|on|viewed)$/.test(h):
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

  renderButtons = ({getParams, getRecordCount, reload, location}) => (
    <div key="renderedButtonsWrapper" className="row mb-3">
      <div key="csvDownloadWrapper" className="col-auto">
        <FileDownload key="unassignedCsvDownload" path={`${assignmentsUrl}.csv`}>
          <span key="csvDownloadButton" className="btn btn-primary clickable btn-info">
            Download Unassigned
          </span>
        </FileDownload>
        <FileDownload key="allCsvDownload" path="/admin/users/responds.csv" emailed>
          <span key="csvDownloadButton" className="ml-3 btn btn-primary clickable btn-info">
            All Responds
          </span>
        </FileDownload>
      </div>
      <div key="renderedButtonsSeparator" className="border border-dark mb-3" style={{minHeight: '38px'}}></div>
      <div key="assignmentFormWrapper" className="col">
        <AssignmentsUploadForm prefix={`${location}-`} key="assignmentUploadForm" url={assignmentsUrl} reload={reload} />
      </div>
      <div key="reassignmentFormWrapper" className="col">
        <AssignmentsReassignForm prefix={`${location}-`} key="reassignmentForm" url={`${assignmentsUrl}/reassign`} getRecordCount={getRecordCount} getParams={getParams} reload={reload} />
      </div>
    </div>

  )

  render() {
    return (
      <div key="assignmentsLookupWrapper" className="Assignments RespondsPage row">
        <div className="col">
          <h3 className="text-center pb-3">Responds</h3>
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
          localStorageKey="adminAssignmentsRespondsAssigned"
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
