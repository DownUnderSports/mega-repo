import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import FileDownload from 'common/js/components/file-download'
import { InlineRadioField } from 'react-component-templates/form-components';
import CalendarField from 'common/js/forms/components/calendar-field'
import LookupTable from 'common/js/components/lookup-table'

const marathonsUrl = '/admin/traveling/gcm_registrations',
      headers = [
        'dus_id',
        'first',
        'last',
        'dob',
        'first_payment',
        'cancel_date',
        'total_payments',
        'category_type',
        'reg_date',
        'confirmation',
      ],
      aliasFields = {
        dob: 'birth_date',
        first_payment: 'first_payment_date',
        reg_date: 'registered_date',
      },
      additionalFilters = [
        'has_passport',
        'travelers',
        'cancels',
      ],
      copyFields = [
        'dus_id'
      ],
      colors = [
        {
          className: 'bg-warning-light',
          description: 'Canceled Traveler'
        },
        {
          className: 'bg-success',
          description: 'Registration Completed'
        },
      ]

export default class GCMRegistrationsIndexPage extends AsyncComponent {
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
      /_date|first_payment|dob/.test(h) ? (
        <div className="row text-dark">
          <div className='col'>
            <CalendarField
              measurable
              closeOnSelect
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
    return `clickable ${u.cancel_date ? 'bg-warning-light' : (u.confirmation ? 'bg-success' : '')}`
  }

  all = (onChange, tableState) => this.hasSectionFilter(tableState) && onChange({cancels: false, travelers: false})
  cancels = (onChange, tableState) => !tableState.cancels && onChange({cancels: true, travelers: false})
  travelers = (onChange, tableState) => !tableState.travelers && onChange({travelers: true, cancels: false})
  togglePassport = (onChange, v) => onChange({has_passport: v || ''})

  hasSectionFilter = (tableState) => tableState.cancels || tableState.travelers

  renderButtons = ({onChange, tableState}) => (
    <div className="row">
      <div className="col-auto form-group">
        <button
          className='btn btn-success'
          onClick={() => this.travelers(onChange, tableState)}
          disabled={!!tableState.travelers}
        >
          Active
        </button>
      </div>
      <div className="col-auto form-group">
        <button
          className='btn btn-danger'
          onClick={() => this.cancels(onChange, tableState)}
          disabled={!!tableState.cancels}
        >
          Canceled
        </button>
      </div>
      <div className="col-auto form-group">
        <button
          className='btn btn-info'
          onClick={() => this.all(onChange, tableState)}
          disabled={!this.hasSectionFilter(tableState)}
        >
          All Travelers
        </button>
      </div>
      <div className="col text-center form-group">
        <div className="row">
          <div className="col-auto ml-5">
            <label>Has Passport?</label>
          </div>
          <div className="col label-hidden">
            <InlineRadioField
              options={[
                {value: '1', label: 'Yes'},
                {value: '0', label: 'No'},
                {value: '', label: 'Any'},
              ]}
              value={tableState.has_passport || ''}
              onChange={(value) => this.togglePassport(onChange, value || '')}
            />
          </div>
        </div>
      </div>
      <div className='col'></div>
    </div>
  )

  render() {
    return (
      <div className="GCMRegistrations IndexPage row">
        <LookupTable
          url={marathonsUrl}
          headers={headers}
          additionalFilters={additionalFilters}
          aliasFields={aliasFields}
          copyFields={copyFields}
          initialSearch={true}
          filterComponent={this.filterComponent}
          rowClassName={this.rowClassName}
          localStorageKey="gcmRegistrationsIndexPage"
          resultsKey="registrations"
          idKey="dus_id"
          tabKey="marathon_registration"
          className="col-12"
          renderButtons={this.renderButtons}
          colors={colors}
        />

        <div className="col-12 my-5">
          <FileDownload path='/admin/marathon_registrations.csv'>
            <span className="btn btn-block btn-lg clickable btn-info">
              Click Here To Download a CSV
            </span>
          </FileDownload>
        </div>
      </div>
    );
  }
}
