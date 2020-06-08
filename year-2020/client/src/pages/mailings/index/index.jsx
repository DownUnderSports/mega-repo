import React from 'react';
import Component from 'common/js/components/component'
import CalendarField from 'common/js/forms/components/calendar-field'
import LookupTable from 'common/js/components/lookup-table'

const mailingsUrl = '/admin/returned_mails',
      headers = [
        'id',
        'dus_id',
        'category',
        'sent',
        'is_home',
        'is_foreign',
        'street',
        'street_2',
        'street_3',
        'city',
        'state',
        'zip',
        'country',
      ],
      copyFields = [
        'id',
        'dus_id',
      ]

export default class MailingsIndexPage extends Component {
  filterComponent = (h, v, onChange, defaultComponent) => (
    h === 'sent' ? (
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

  rowClassName(m) {
    console.log(m)
    return m.failed ? 'clickable bg-danger' : 'clickable'
  }

  render() {
    return (
      <div className="Mailings IndexPage row">
        <LookupTable
          url={mailingsUrl}
          headers={headers}
          copyFields={copyFields}
          initialSearch={true}
          filterComponent={this.filterComponent}
          rowClassName={this.rowClassName}
          localStorageKey="adminMailingsIndexState"
          resultsKey="mailings"
          tabKey="mailing"
          className="col-12"
        />
      </div>
    );
  }
}
