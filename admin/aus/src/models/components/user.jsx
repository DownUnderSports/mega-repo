import React from 'react'
import BaseModelComponent from 'models/components/base'
import TravelerBusModelComponent from 'models/components/traveler-bus'
import UserModel from 'models/user'
import SortableTable from 'components/sortable-table'
import { SelectField } from 'react-component-templates/form-components';

const tableHeaders = [
        "dusId",
        "first",
        "last",
        "getRelations",
      ], headerAliases = {
        id:    'User ID',
        dusId: 'DUS ID',
        first: 'First',
        last:  'Last',
        getRelations: 'Related Users'
      },
      SelectFieldWrapper = (props) => {
        const { data = [] } = props.travelerBusesModel || {}

        return <SelectField
          id="select_bus_for_users"
          viewProps={{
            className:'form-control',
          }}
          options={(data || []).map((d) => ({ value: d.id, label: d.asString }))}
          filterOptions={{
            indexes: ['label'],
          }}
          onChange={props.onChange}
          value={props.value}
          label="Select Bus"
        />
      }

export default class UserModelComponent extends BaseModelComponent {
  model = UserModel

  constructor(props) {
    super(props)

    this.state.page = 0
    this.state.filteredData = []
    this.state.selectedBus = null
  }

  _phoneFormat(phone) {
    phone = String(phone || '')
    switch (true) {
      case /^\+/.test(phone):
        return phone
      case /^0/.test(phone):
        return `+61${phone.replace(/^0|[^0-9]/g, '')}`
      case /^[0-9]{3}-?[0-9]{3}-?[0-9]{4}$/.test(phone):
        return `+1-${phone}`;
      default:
        return phone
    }
  }

  _cellRenderer = (row, header) =>
    header === 'getRelations'
      ? (
        <table className="table table-secondary table-striped mb-0 p-0">
          {
            <thead>
              <tr>
                <td>
                  Relationship
                </td>
                <td>
                  Name
                </td>
                <td>
                  Gender
                </td>
                <td>
                  Phone
                </td>
                <td>
                  Email
                </td>
              </tr>
            </thead>
          }
          <tbody>
            {
              (row.relations || []).map((r, ri) => (
                <tr key={`${row.id}.${r.id}.${ri}`}>
                  <td>
                    { r.relationship }
                  </td>
                  <td>
                    { r.name }
                  </td>
                  <td>
                    { r.gender }
                  </td>
                  <td>
                    { !!r.phone && <a href={`tel:${this._phoneFormat(r.phone)}`}>{r.phone}</a> }
                  </td>
                  <td>
                    { !!r.email && <a href={`mailto:${r.email}`}>{r.email}</a> }
                  </td>
                </tr>
              ))
            }
          </tbody>
        </table>
      )
      : row[header]

  _onBusChange = (_, { value }) => {
    this.setState({ selectedBus: value })
  }

  displayTable = () =>
    <SortableTable
      headers={tableHeaders}
      data={this.state.data.filter(v => !this.state.selectedBus || (v.busIds || []).includes(this.state.selectedBus)) || []}
      headerAliases={headerAliases}
      renderer={this._cellRenderer}
    >
      <TravelerBusModelComponent>
        <SelectFieldWrapper value={this.state.selectedBus} onChange={this._onBusChange} />
      </TravelerBusModelComponent>
    </SortableTable>

    // capacity:
    // 0
    // color:
    // "Gold"
    // createdAt:
    // "2019-05-31T17:27:44.151474-06:00"
    // details:
    // null
    // hotelId:
    // 2
    // id:
    // 1
    // name:
    // "Brumbies"
    // sportAbbr:
    // "FB"
    // sportFull:
    // "Football"
    // sportId:
    // 4
    // updatedAt:
    // "2019-07-03T16:32:25.309970-06:00"


}
