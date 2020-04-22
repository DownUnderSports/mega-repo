import React, { Component } from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
import AmbassadorForm from 'forms/ambassador-form'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'


export const ambassadorsUrl = '/admin/users/:id/ambassadors/:ambassador_record_id.json'

export default class AmbassadorInfo extends Component {
  constructor(props) {
    super(props)
    this.state = { ambassadors: [], reloading: !!this.props.id, showForm: false, formIdx: 0 }
  }

  async componentDidMount(){
    if(this.props.id) await this.getRecords()
  }

  async componentDidUpdate(prevProps) {
    if(prevProps.id !== this.props.id) await this.getRecords()
  }

  componentWillUnmount() {
    this._unmounted = true
    this.abortFetch()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  getRecords = async (showForm = false) => {
    if(this._unmounted) return false
    if(!this.props.id) return this.setState({showForm})
    this.setState({reloading: true})
    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('UserInfo: No User ID')
      this._fetchable = fetch(ambassadorsUrl.replace(':id', this.props.id).replace("/:ambassador_record_id", ''), {timeout: 5000})
      const result = await this._fetchable,
            retrieved = await result.json(),
            formIdx = showForm ? retrieved.ambassador_records.findIndex(record => +record.id === +showForm) : 0

      this._unmounted || this.setState({
        reloading: false,
        ambassadors: retrieved.ambassador_records,
        showForm,
        formIdx
      })
    } catch(e) {
      console.error(e)
      this._unmounted || this.setState({
        reloading: false,
        user: {},
      })
    }
  }

  openAmbassadorForm = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.getRecords(e.currentTarget.dataset.id)
  }

  onSuccess = () => this.getRecords(false)
  onCancel = () => this.setState({showForm: false})

  render() {
    const {
      ambassadors = [],
      reloading = false,
      showForm
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
          showForm ? (
            <AmbassadorForm
              key={ showForm || 'new'}
              id={ showForm === "new" ? '' : showForm }
              userId={ this.props.id }
              onSuccess={ this.onSuccess }
              onCancel={ this.onCancel }
              ambassador={showForm === "new" ? {} : this.state.ambassadors[this.state.formIdx]}
            />
          ) : (
            <table className="table m-0">
              <thead>
                <tr>
                  <th>
                    Relationship
                  </th>
                  <th>
                    DUS ID
                  </th>
                  <th>
                    First
                  </th>
                  <th>
                    Last
                  </th>
                  <th>
                    Email
                  </th>
                  <th>
                    Phone
                  </th>
                </tr>
              </thead>
              <tbody>
                {
                  ambassadors.map(ambassador => (
                    <tr
                      className="clickable"
                      key={`ambassador_list.${ambassador.id}`}
                      data-id={ambassador.id}
                      onClick={ this.openAmbassadorForm }
                    >
                      <th>
                        { ambassador.category } ({ ambassador.relationship || 'none'})
                      </th>
                      <th>
                        { ambassador.dus_id }
                      </th>
                      <th>
                        { ambassador.first }
                      </th>
                      <th>
                        { ambassador.last }
                      </th>
                      <th>
                        { ambassador.types_array.some(type => type === "email") ? "Yes" : "No" }
                      </th>
                      <th>
                        { ambassador.types_array.some(type => type === "phone") ? "Yes" : "No" }
                      </th>
                    </tr>
                  ))
                }
              </tbody>
              <tfoot>
                <tr>
                  <td colSpan="5">
                    <button
                      type="button"
                      onClick={ this.openAmbassadorForm }
                      className="btn btn-block btn-primary"
                      data-id="new"
                    >
                      New
                    </button>
                  </td>
                </tr>
              </tfoot>
            </table>
          )
        }
      </DisplayOrLoading>
    );
  }
}
