import React from 'react';
import Component from 'common/js/components/component/async';
import { DisplayOrLoading, CardSection } from 'react-component-templates/components';
import CreditForm from 'common/js/forms/credit-form';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box';
;

export default class UserCreditsShowPage extends Component {
  constructor(props){
    super(props)
    this.action = `${this.props.location.pathname.replace('/new', '')}.json`
    this.state = { credit: {}, ...this.state }
  }

  afterMount = async () => {
    return await this.findCredit()
  }

  componentDidUpdate(prevProps) {
    if(!prevProps.credit || !this.props.credit || (this.props.match.params.creditId !== prevProps.match.params.creditId)) {
      this.findCredit()
    }
  }

  findCredit = async () => {
    const credit = await this.props.findCredit(this.props.match.params.creditId)
    return this._isMounted && credit && this.setStateAsync({ credit, loading: false })
  }

  render() {
    const { match: { params: { creditId } } } = this.props || {},
          { credit = {}, loading = true } = this.state || {}

    return (
      <div key={creditId}>
        <DisplayOrLoading
          display={!loading}
          message='LOADING...'
          loadingElement={
            <JellyBox />
          }
        >
          <CardSection
            className='mb-3'
            label={credit.name || 'New Credit'}
            contentProps={{className: 'list-group'}}
          >
            <div className="list-group-item">
              <CreditForm
                key={creditId}
                {...credit}
                categories={this.props.categories || []}
                getCredits={this.props.getCredits}
                url={this.action}
                indexUrl={this.props.indexUrl}
                history={this.props.history}
              />
            </div>
          </CardSection>
        </DisplayOrLoading>
      </div>
    )
  }
}
