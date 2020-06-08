import React, { Component } from 'react';
import LookupTable from 'common/js/components/lookup-table'

const schoolsUrl = '/admin/schools',
      headers = [
        'pid',
        'name',
        'allowed',
        'allowed_home',
        'closed',
        'street',
        'city',
        'state',
        'zip',
      ],
      copyFields = [
        'pid'
      ]

export default class SchoolsIndexPage extends Component {

  filterComponent = (h,v,c,d) => /(allowed|closed)/.test(h) ? (
    <select
      className='form-control'
      onChange={c}
      value={v}
    >
      <option value=""></option>
      <option value="true">true</option>
      <option value="false">false</option>
    </select>
  ) : d(h,v,c)

  rowClassName(s){
    return (s.closed || !s.allowed_home) ? 'clickable bg-danger' : (!s.allowed ? 'clickable bg-warning' : 'clickable')
  }

  render() {
    return (
      <div className="Schools IndexPage row">
        <LookupTable
          url={schoolsUrl}
          headers={headers}
          copyFields={copyFields}
          initialSearch={true}
          filterComponent={this.filterComponent}
          rowClassName={this.rowClassName}
          localStorageKey="adminSchoolsIndexState"
          resultsKey="schools"
          tabKey="school"
          className='col-12'
        />
      </div>
    );
  }
}
