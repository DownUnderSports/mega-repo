import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import FileDownload from 'common/js/components/file-download'
import { BooleanField } from 'react-component-templates/form-components';
import CalendarField from 'common/js/forms/components/calendar-field'
import LookupTable from 'common/js/components/lookup-table'
import canUseDOM from 'common/js/helpers/can-use-dom'

import MeetingRegistrationUploadForm from 'forms/meeting-registration-upload-form'

export const usersUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/users`,
      headers = [
        'dus_id',
        'first',
        'middle',
        'last',
        'suffix',
        'category_type',
        'email',
        'phone',
        'state',
        'sport',
        'depart_date',
        'join_date',
        'cancel_date',
      ],
      aliasFields = {
        depart_date: 'departing_date',
        join_date: 'joined_at',
        sport: 'sport_abbr',
        state: 'state_abbr',
      },
      additionalFilters = [
        'travelers',
        'cancels',
        'wrong_school',
      ],
      copyFields = [
        'dus_id'
      ],
      colors = [
        {
          className: 'bg-danger',
          description: 'Do Not Contact'
        },
        {
          className: 'bg-warning-light',
          description: 'Canceled Traveler'
        },
        {
          className: 'bg-success',
          description: 'Active Traveler'
        },
        {
          className: 'bg-light border-orange',
          description: 'Wrong School'
        },
      ]

export default class UsersIndexPage extends AsyncComponent {
  filterComponent = (h, v, onChange, defaultComponent) =>
    h === 'category_type' ? (
      <select
        className='form-control'
        onChange={(ev) => onChange(h, ev.target.value)}
        value={v}
      >
        <option value=""></option>
        <option value="athlete">Athlete</option>
        <option value="coach">Coach</option>
        <option value="official">Official</option>
        <option value="staff">Staff</option>
        <option value="supporter">Supporter</option>
      </select>
    ) : (
      /_date/.test(h) ? (
        <div className="row text-dark">
          <div className='col'>
            <CalendarField
              measurable
              closeOnSelect
              skipExtras
              className='form-control'
              name={h}
              type='text'
              pattern={"\\d{4}-\\d{2}-\\d{2}"}
              onChange={(e, o) => onChange(h, o.value)}
              value={v}
            />
          </div>
        </div>
      ) : defaultComponent(h, v)
    )

  rowClassName(u){
    return `clickable ${u.contactable ? (u.traveling ? (u.cancel_date ? 'bg-warning-light' : 'bg-success') : '') : 'bg-danger'} ${u.wrong_school ? 'border-orange' : ''}`
  }

  all = (onChange, tableState) => this.hasSectionFilter(tableState) && onChange({cancels: false, travelers: false})
  cancels = (onChange, tableState) => !tableState.cancels && onChange({cancels: true, travelers: false})
  travelers = (onChange, tableState) => !tableState.travelers && onChange({travelers: true, cancels: false})
  toggleSchool = (onChange, tableState) => onChange({wrong_school: !tableState.wrong_school})

  hasSectionFilter = (tableState) => tableState.cancels || tableState.travelers

  renderButtons = ({onChange, tableState}) => (
    <div className="row">
      <div className="col-auto form-group">
        <button
          className='btn btn-success'
          onClick={() => this.travelers(onChange, tableState)}
          disabled={!!tableState.travelers}
        >
          Travelers
        </button>
      </div>
      <div className="col-auto form-group">
        <button
          className='btn btn-danger'
          onClick={() => this.cancels(onChange, tableState)}
          disabled={!!tableState.cancels}
        >
          Cancels
        </button>
      </div>
      <div className="col-auto form-group">
        <button
          className='btn btn-info'
          onClick={() => this.all(onChange, tableState)}
          disabled={!this.hasSectionFilter(tableState)}
        >
          All Users
        </button>
      </div>
      <div className='col'></div>
      <div className="col text-center form-group">
        <BooleanField
          checked={!!tableState.wrong_school}
          label='Wrong School?'
          toggle={() => this.toggleSchool(onChange, tableState)}
          skipTopLabel
        />
      </div>
      <div className='col'></div>
    </div>
  )

  render() {
    return (
      <div className="Users IndexPage row">
        <LookupTable
          additionalFilters={additionalFilters}
          aliasFields={aliasFields}
          colors={colors}
          className="col-12"
          copyFields={copyFields}
          filterComponent={this.filterComponent}
          headers={headers}
          idKey="dus_id"
          initialSearch={true}
          localStorageKey="adminUsersIndexState"
          renderButtons={this.renderButtons}
          resultsKey="users"
          rowClassName={this.rowClassName}
          showUrl="/admin/users"
          tabKey="user"
          url={usersUrl}
        />

        <div className="col-6 my-5">
          <FileDownload path='/admin/video_views.csv'>
            <span className="btn btn-block btn-lg clickable btn-info">
              Click Here To Download Viewed Videos List
            </span>
          </FileDownload>
        </div>
        <div className="col-6 my-5">
          <FileDownload path='/admin/users.csv'>
            <span className="btn btn-block btn-lg clickable btn-primary">
              Click Here To Download Travelers List
            </span>
          </FileDownload>
        </div>
        <div className="col-12 my-5">
          <MeetingRegistrationUploadForm />
        </div>
      </div>
    );
  }
}
