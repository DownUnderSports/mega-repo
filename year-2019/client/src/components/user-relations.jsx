import React, { Component } from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
//import authFetch from 'common/js/helpers/auth-fetch'
import canUseDOM from 'common/js/helpers/can-use-dom'
import UserInfo from 'components/user-info'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'


const usersUrl = `${canUseDOM ? '' : 'http://localhost:3000'}/admin/users`

export default class UserRelations extends Component {
  constructor(props) {
    super(props)
    this.state = { relations: [], reloading: true }
  }

  async componentDidMount(){
    await this.getRelations()
  }

  componentWillUnmount() {
    this._unmounted = true
    this.abortFetch()
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.getRelations()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  getRelations = async () => {
    if(this._unmounted) return false
    this.setState({reloading: true})
    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('UserRelations: No User ID')
      this._fetchable = fetch(`${usersUrl}/${this.props.id}/relations.json`, {timeout: 5000})
      const result = await this._fetchable,
            retrieved = await result.json()

      this._unmounted || this.setState({
        reloading: false,
        showForm: false,
        ...retrieved,
      }, () => this.props.setRelations(this.state.relations))

    } catch(e) {
      console.error(e)
      this._unmounted || this.setState({
        reloading: false,
        relations: [],
      }, () => this.props.setRelations(this.state.relations))
    }
  }

  capitalize(str) {
    return str[0].toUpperCase() + str.slice(1)
  }

  removeRelation = (i) => {
    const {relations = []} = this.state
    this.setState({relations: [...relations.slice(0, i), ...relations.slice(i + 1)]})
  }

  render() {
    const {
      relations = [],
      reloading = false,
    } = this.state || {}

    return (
      <DisplayOrLoading
        display={!reloading}
        message='LOADING...'
        loadingElement={
          <JellyBox />
        }
      >
        {
          relations ? (
            relations.map((r, k) => (
              <UserInfo
                key={r.related_user_id || k}
                header={this.capitalize(r.relationship || 'New Relation') + ' Info'}
                id={r.related_user_id}
                formId={r.id}
                relationship={r.relationship}
                showRelationship={r.showRelationship || r.relationship}
                url={ `${usersUrl}/${this.props.id}/relations` }
                onSuccess={() => this.getRelations()}
                onCancel={ !r.id && (() => this.removeRelation(k))}
              />
            ))
          ) : (
            'No Relations'
          )
        }
        <button className='mt-3 btn-block btn-primary' onClick={() => this.setState({relations: [...this.state.relations, {showRelationship: true}]})}>
          Add Relation
        </button>
      </DisplayOrLoading>
    );
  }
}
