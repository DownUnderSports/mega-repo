import React from 'react';
import Component from 'common/js/components/component'
import { Link } from 'react-component-templates/components';

const recapsUrl = '/admin/assignments/recaps'

export default class RecapSummary extends Component {
  get id() {
    return this.props.id || (this.props.recap || {}).user_id
  }

  get userId() {
    try {
      return (new URLSearchParams(window.location.search)).get("userId")
    } catch(err) {
      return null
    }
  }

  setUser = (ev) => {
    window.location.href = `${recapsUrl}?userId=${this.id}`
  }

  unsetUser = (ev) => {
    window.location.href = recapsUrl
  }

  render() {
    const { id = '', recap = {} } = this.props
    return (
      <div className="col-12">
        <h3>
          {
            !!this.userId && (
              <Link
                to={`${recapsUrl}?userId=${id || recap.user_id}`}
                onClick={this.unsetUser}
                className="float-right"
              >
                &lt;&lt; Back
              </Link>
            )
          }
          <Link
            to={`${recapsUrl}?userId=${id || recap.user_id}`}
            onClick={this.setUser}
          >
            { recap.name }
          </Link>
        </h3>
        <div className="row form-group">
          <div className="col-3">
            <ul className="list-group">
              <li className="list-group-item list-group-item-info">
                Audits Recorded: { recap.total_audits }
              </li>
            </ul>
          </div>
          <div className="col-3">
            <ul className="list-group">
              <li className="list-group-item list-group-item-info">
                Users Modified: { recap.users_modified }
              </li>
            </ul>
          </div>
          <div className="col-3">
            <ul className="list-group">
              <li className="list-group-item list-group-item-info">
                Notes Made: { recap.notes_made }
              </li>
            </ul>
          </div>
          <div className="col-3">
            <ul className="list-group">
              <li className="list-group-item list-group-item-info">
                Travel Package Changes: { recap.package_modifications }
              </li>
            </ul>
          </div>
        </div>
        <div className="row form-group">
          <div className="col-12">
            <h4>
              Summary: <span className="badge float-right">Submitted: { recap.submitted_time }</span>
            </h4>
            <textarea
              name={`staff_recap_${ recap.id }_log`}
              rows="8"
              className="form-control"
              value={recap.log || ''}
              readonly
            />
          </div>
        </div>
      </div>
    )
  }
}
