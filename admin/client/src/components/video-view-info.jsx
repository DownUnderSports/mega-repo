import React, { Component } from 'react';
import VideoForm from 'forms/video-view-form'
import CopyClip from 'common/js/helpers/copy-clip'

export default class RegistrationInfo extends Component {
  constructor(props) {
    super(props)
    this.state = { showForm: !this.props.id }
  }

  openMeetingForm = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.setState({showForm: true})
  }

  copyLink = (e) => {
    e.preventDefault()
    e.stopPropagation()
    CopyClip.prompted(`https://www.downundersports.com/videos/${String(this.props.category)[0]}/${this.props.user_id}`)
  }

  copyDirectLink = (e) => {
    e.preventDefault()
    e.stopPropagation()
    CopyClip.prompted(this.props.link)
  }

  render() {
    const {
      id,
      video_id,
      user_id,
      duration = '00:00:00',
      watched = false,
      first_viewed = false,
      first_watched = false,
      last_viewed = false,
      category,
      link
    } = this.props || {}

    return this.state.showForm ? (
      <VideoForm
        id={ id }
        userId={ user_id }
        onSuccess={ this.props.onSuccess || (() => this.setState({showForm: false})) }
        onCancel={ this.props.onCancel || (() => this.setState({showForm: false}))}
        url={ this.props.url || '' }
        view={{...this.props}}
      />
    ) : (
      <div className="list-group-item clickable" onClick={this.openMeetingForm}>
        <div className={`row ${watched && 'text-success'}`}>
          <div className="col">
            <table className="table table-sm table-borderless">
              <tbody>
                <tr>
                  <th>
                    Category:
                  </th>
                  <td>
                    { category } ({ video_id })
                  </td>
                  <th>
                    Link:
                  </th>
                  <td className="copyable" onClick={this.copyLink}>
                    https://www.downundersports.com/videos/{String(category)[0]}/{user_id}
                  </td>
                </tr>
                <tr>
                  <td colSpan="2"></td>
                  <th>
                    Direct Link:
                  </th>
                  <td className="copyable" onClick={this.copyDirectLink}>
                    {link}
                  </td>
                </tr>
                <tr>
                  <th>
                    First Viewed:
                  </th>
                  <td>
                    { first_viewed || 'Not Opened' }
                  </td>
                  <th>
                    Last Viewed:
                  </th>
                  <td>
                    { last_viewed }
                  </td>
                </tr>
                <tr>
                  <th>
                    Viewed For:
                  </th>
                  <td>
                    { duration }
                  </td>
                  <th>
                    {
                      watched ? 'Marked as Watched On:' : 'Not Fully Watched'
                    }
                  </th>
                  <td>
                    { first_watched }
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    );
  }
}
