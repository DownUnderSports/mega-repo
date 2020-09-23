import React, { Component } from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
import AmbassadorForm from 'forms/ambassador-form'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import RunningDots from 'load-awesome-react-components/dist/ball/running-dots'

export const ambassadorsUrl = '/admin/users/:id/ambassadors/:ambassador_record_id.json'

const Ambassador = ({ ambassador, openForm }) =>
  <tr
    className="clickable"
    key={`ambassador_list.${ambassador.id}`}
    data-id={ambassador.id}
    onClick={ openForm }
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

export default class AmbassadorInfo extends Component {
  state = { ambassadors: [], reloading: false , showForm: false, formIdx: 0 }

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

    if(!this.props.id) return this.setState({ showForm })

    this.setState({ reloading: true })

    try {
      this.abortFetch()
      if(!this.props.id) throw new Error('UserInfo: No User ID')
      this._fetchable = fetch(ambassadorsUrl.replace(':id', this.props.id).replace("/:ambassador_record_id", ''), {timeout: 5000})
      const result = await this._fetchable,
            retrieved = await result.json(),
            formIdx = showForm ? retrieved.ambassador_records.findIndex(record => +record.id === +showForm) : 0

      this._unmounted || this.setState({
        reloading: false,
        ambassadors: retrieved.ambassador_records || [],
        showForm,
        formIdx
      })
    } catch(e) {
      console.error(e)
      this._unmounted || this.setState({
        reloading: false,
        ambassadors: [],
      })
    }
  }

  openAmbassadorForm = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.getRecords(e.currentTarget.dataset.id)
  }

  onSuccess = () => this.getRecords(false)
  onCancel = () => this.setState({ showForm: false })

  showAmbassador = (ambassador, i) =>
    <Ambassador
      key={`ambassador-list.${ambassador.id || `new-${i}`}`}
      ambassador={ambassador}
      openForm={ this.openAmbassadorForm }
    />

  render() {
    const {
      ambassadors = [],
      reloading = false,
      showForm
    } = this.state || {}

    return (
      <DisplayOrLoading
        display={!reloading || (!!ambassadors.length && !showForm)}
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
                {
                  !!reloading && (
                    <tr>
                      <th colSpan="6">
                        <div className="d-flex justify-content-center my-3">
                          <RunningDots className="la-dark la-2x" />
                        </div>
                      </th>
                    </tr>
                  )
                }
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
                { ambassadors.map(this.showAmbassador) }
              </tbody>
              <tfoot>
                <tr>
                  <td colSpan="6">
                    <button
                      type="button"
                      onClick={ this.openAmbassadorForm }
                      className="btn btn-block btn-primary"
                      data-id="new"
                      disabled={reloading}
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
