import React from 'react';
import Component from 'common/js/components/component/async';
import { DisplayOrLoading, CardSection } from 'react-component-templates/components';
import DebitForm from 'common/js/forms/debit-form';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box';
;

export default class UserDebitsShowPage extends Component {
  constructor(props){
    super(props)
    this.action = `${this.props.location.pathname.replace('/new', '')}.json`
    this.state = { debit: {}, ...this.state }
  }

  afterMount = async () => {
    return await this.findDebit()
  }

  componentDidUpdate(prevProps) {
    if(!prevProps.debit || !this.props.debit || (this.props.match.params.debitId !== prevProps.match.params.debitId)) {
      this.findDebit()
    }
  }

  findDebit = async () => {
    const debit = await this.props.findDebit(this.props.match.params.debitId)
    return this._isMounted && debit && this.setStateAsync({ debit, loading: false })
  }

  render() {
    const { match: { params: { debitId } } } = this.props || {},
          { debit = {}, loading = true } = this.state || {},
          { base_debit = {} } = debit

    return (
      <div key={debitId}>
        <DisplayOrLoading
          display={!loading}
          message='LOADING...'
          loadingElement={
            <JellyBox />
          }
        >
          <CardSection
            className='mb-3'
            label={debit.name || base_debit.name || 'New Debit'}
            contentProps={{className: 'list-group'}}
          >
            <div className="list-group-item">
              <DebitForm
                key={debitId}
                {...debit}
                getDebits={this.props.getDebits}
                baseDebits={this.props.baseDebits}
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
