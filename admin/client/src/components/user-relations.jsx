import React, { Component } from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
import UserInfo from 'components/user-info'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import RunningDots from 'load-awesome-react-components/dist/ball/running-dots'


const usersUrl = '/admin/users'

const capitalize = (str) => str[0].toUpperCase() + str.slice(1)

const Relation = ({ relation, onSuccess, onCancel, url }) =>
  <UserInfo
    key={relation.id || "new-relation"}
    header={capitalize(relation.relationship || 'New Relation') + ' Info'}
    id={relation.related_user_id}
    formId={relation.id}
    relationship={relation.relationship}
    showRelationship={relation.showRelationship || relation.relationship}
    url={url}
    onSuccess={onSuccess}
    onCancel={ !relation.id && onCancel }
  />

export default class UserRelations extends Component {
  constructor(props) {
    super(props)
    this.state = { relations: [], hasRelation: false, reloading: true }
  }

  async componentDidMount(){
    await this.getRelations()
  }

  componentWillUnmount() {
    this._unmounted = true
    this.abortFetch()
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) return await this.getRelations()

    const hasRelation = !!(this.state.relations && this.state.relations.length)
    if(this.state.hasRelation !== hasRelation) this.setState({ hasRelation })
  }

  get mapRelations() {
    return (this.state.hasRelation && this.state.relations)
      ? this.state.relations.map(this.renderRelation)
      : 'No Relations'
  }

  onSuccess = () => this.getRelations()

  renderRelation = (relation, i) =>
    <Relation
      key={relation.id || `new-rel-${i}`}
      relation={relation}
      onSuccess={this.onSuccess}
      onCancel={() => this.removeRelation(i)}
      url={`${usersUrl}/${this.props.id}/relations`}
    />

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  forceGetRelations = () => this.getRelations(true)

  getRelations = async (force = false) => {
    if(this._unmounted) return false
    this.setState({reloading: true})
    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('UserRelations: No User ID')
      this._fetchable = fetch(`${usersUrl}/${this.props.id}/relations.json?force=${force ? 1 : 0}`, {timeout: 5000})
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

  addRelation = () =>
    this.setState({
      relations: [
        ...this.state.relations,
        { showRelationship: true }
      ]
    })

  removeRelation = (i) => {
    const {relations = []} = this.state
    this.setState({relations: [...relations.slice(0, i), ...relations.slice(i + 1)]})
  }

  render() {
    const {
      hasRelation = false,
      reloading = false,
    } = this.state || {}

    return (
      <>
        <div key="title" className="row">
          <div className="col-auto">
          </div>
          <div className="col">
            <h2 className='text-center mb-3'>Related Users</h2>
          </div>
          <div className="col-auto">
            {
              !reloading && (
                <div className="d-flex justify-content-center">
                  <i className="ml-3 material-icons clickable" onClick={this.forceGetRelations}>
                    refresh
                  </i>
                </div>
              )
            }
          </div>
        </div>
        {
          !!reloading && hasRelation && (
            <div key="loading-dots" className="d-flex justify-content-center">
              <RunningDots className="la-dark la-2x" />
            </div>
          )
        }
        <DisplayOrLoading
          key="relations-list"
          display={!reloading || hasRelation}
          message='LOADING...'
          loadingElement={
            <JellyBox />
          }
        >
          { this.mapRelations }
          <button className='mt-3 btn-block btn-primary' onClick={this.addRelation}>
            Add Relation
          </button>
        </DisplayOrLoading>
      </>
    );
  }
}
