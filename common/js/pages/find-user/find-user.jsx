import React, { Component } from 'react';
import pixelTracker from 'common/js/helpers/pixel-tracker'
import FindUser from 'common/js/components/find-user'
import { NotFoundPage } from 'react-component-templates/pages'
import './find-user.css'

export default class FindUserPage extends Component {
  componentDidMount() {
    pixelTracker('track', 'PageView')
  }

  render() {
    try {
      const { match: { params: { dusId } } } = this.props
      return (
        <div className="my-5">
          {
            /^[A-Z]{3}-?[A-Z]{3}$/.test(`${dusId}`.toUpperCase())
              ? <FindUser key={dusId} dusId={`${dusId}`.toUpperCase()} url='/infokit' travelerUrl={'/payment'} search={this.props.location.search} />
              : <NotFoundPage {...this.props} />
          }
        </div>
      );
    } catch (e) {
      return <NotFoundPage {...this.props} />
    }
  }
}
