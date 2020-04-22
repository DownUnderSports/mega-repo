import React from 'react'
import Component from 'common/js/components/component'
import LegalUploadForm from 'common/js/forms/legal-upload-form'
import { CardSection } from 'react-component-templates/components';

export default class LegalDocumentsPage extends Component {
  constructor(props){
    super(props)
    this.state = {}
  }

  async componentDidMount(){
    await this.fetchUser()
  }

  fetchUser = async () => {
    const { match: { params: { userId } } } = this.props,
          fetchUrl = `/api/departure_checklists/${userId}`

    if(userId) {
      let val = {}
      try {
        const res = await fetch(fetchUrl)
        val = await res.json() || {}
      } catch(_) {
        val = {}
      }
      return await this.setStateAsync(val)
    }
  }

  backToChecklist = () => this.props.history.push(`/departure-checklist/${this.props.match.params.userId}`)

  render() {
    return (
      <CardSection
        className="my-5"
        label={<div>
          Legal Document
          {this.state.dus_id && `: ${this.state.name} (${this.state.dus_id})`}
        </div>}
        contentProps={{className: 'list-group'}}
      >
        {
          this.state.dus_id ? (
            <LegalUploadForm id={this.props.match.params.userId} {...this.state} onSuccess={this.backToChecklist} />
          ) : (
            <div className="list-group-item">
              Please contact a Down Under Sports representative for your departure checklist link.
              <ul>
                <li>Email: <a href="mailto:mail@downundersports.com">mail@downundersports.com</a></li>
                <li>Phone: <a href="tel:435-753-4732">435-753-4732</a></li>
              </ul>
            </div>
          )
        }
      </CardSection>
    );
  }
}
