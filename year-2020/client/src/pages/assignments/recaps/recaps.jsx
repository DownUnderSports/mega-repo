import React, { Suspense, lazy } from 'react';
import Component from 'common/js/components/component'
import { DisplayOrLoading } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import { Objected } from 'react-component-templates/helpers';

const RecapSummary = lazy(() => import(/* webpackChunkName: "assignments-recap-summary" */ 'pages/assignments/recaps/recap-summary'))
const recapsUrl = '/admin/assignments/recaps'

export default class AssignmentsRecapsPage extends Component {
  state = {
    users: null,
    recap: null,
    recaps: null,
    errors: null,
    successful: null,
    usersErrors: null,
    recapsErrors: null
  }

  async componentDidMount(){
    this.setState({ submitting: true })

    const userId = this.userId
    if(userId) {
      await this.listRecaps()
    } else {
      await this.listUsers()
      await this.getRecap()
    }

    this.setState({ submitting: false })
  }

  get userId() {
    try {
      return (new URLSearchParams(window.location.search)).get("userId")
    } catch(err) {
      return null
    }
  }

  handleErrors = async (err, key = "errors") => {
    console.error(err)

    try {
      this.setState({ [key || "errors"]: (await err.response.json()).errors })
    } catch(e) {
      this.setState({ [key || "errors"]: [ err.message || err.toString() ] })
    }
  }

  listRecaps = async () => {
    const options = {
      method: 'GET',
      headers: {
        "Content-Type": "application/json; charset=utf-8"
      },
    }

    try {
      const result = await fetch(`${recapsUrl}/${this.userId}.json`, options),
            json   = await result.json()

      this.setState({ recaps: json.recaps, recapsErrors: json.errors })
    } catch (err) {
      this.setState({ recaps: null })
      this.handleErrors(err, "recapsErrors")
    }
  }

  listUsers = async () => {
    const options = {
      method: 'GET',
      headers: {
        "Content-Type": "application/json; charset=utf-8"
      },
    }

    try {
      const result = await fetch(`${recapsUrl}.json`, options),
            json   = await result.json()

      this.setState({ users: json.users, usersErrors: json.errors })
    } catch (err) {
      this.setState({ users: null })
      this.handleErrors(err, "usersErrors")
    }
  }

  getRecap = async () => {
    const options = {
      method: 'GET',
      headers: {
        "Content-Type": "application/json; charset=utf-8"
      },
    }

    try {
      const result = await fetch(`${recapsUrl}/new.json`, options),
            json   = await result.json()

      this.setState({ recap: json.recap, errors: json.errors })
    } catch (err) {
      this.setState({ recap: null })
      this.handleErrors(err)
    }

    this.setState({ submitting: false })
  }

  onLogChange = (ev) => {
    const value = String(ev.currentTarget.value || '')
    this.setState((state, _) => {
      const recap = Objected.deepClone(state.recap || {})
      recap.log = value
      return { recap }
    })
  }

  onFormKeyDown = (e) => {
    if((e.keyCode === 13) && e.ctrlKey) this.onSubmit(e)
  }

  onSubmit = (e) => {
    e.preventDefault();
    this.setState({errors: null, submitting: true, successful: false})
    this.handleSubmit()
  }

  handleSubmit = async () => {
    try {
      const recap = Objected.deepClone(this.state.recap || {})

      if(!recap.log) throw new Error("No Recap Given")

      const result =  await fetch(this.action, {
        method: this.props.method || this.props.id ? 'PATCH' : 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ recap })
      });

      await result.json()
      await this.getRecap()
      if(this.state.users) await this.listUsers()

      this.setState({ submitting: false, successful: true })
    } catch(err) {
      this.handleErrors(err)
    }
  }

  render() {
    const {
      users,
      recap,
      recaps,
      errors,
      successful,
      usersErrors,
      recapsErrors,
    } = this.state

    return (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox />
        }
      >
        <div key="recapWrapper" className="Assignments RecapsPage row">
          <div className="col-12">
            <h3 className="text-center pb-3">Recaps</h3>
          </div>
          {
            recap && (
              <form
                action={this.action}
                method='post'
                className='col-12'
                onSubmit={this.onSubmit}
                onKeyDown={this.onFormKeyDown}
                autoComplete="off"
              >
                <input
                  autoComplete="false"
                  type="text"
                  name="autocomplete"
                  style={{display: 'none'}}
                />
                {
                  !!successful && <div className="alert alert-success form-group">
                    Submitted!
                  </div>
                }
                {
                  errors && <div className="alert alert-danger form-group" role="alert">
                    {
                      errors.map((v, k) => (
                        <div className='row' key={k}>
                          <div className="col">
                            { v }
                          </div>
                        </div>
                      ))
                    }
                  </div>
                }
                <div className="form-group">
                  <label htmlFor="recap-log">
                    Please summarize your work day
                  </label>
                  <textarea
                    name="recap[log]"
                    id="recap-log"
                    rows="10"
                    className="form-control"
                    value={recap.log || ""}
                    onChange={this.onLogChange}
                  />
                </div>
                <button type="submit" className="btn btn-primary btn-block">
                  Submit Recap
                </button>
                <hr/>
              </form>
            )
          }
          <div className="col-12">
            {
              recapsErrors && <div className="alert alert-danger form-group" role="alert">
                {
                  recapsErrors.map((v, k) => (
                    <div className='row' key={k}>
                      <div className="col">
                        Extended Access Denied: { v }
                      </div>
                    </div>
                  ))
                }
              </div>
            }
          </div>
          {
            !!recaps
              && Array.isArray(recaps)
              && recaps
                  .map(
                    (recap) =>
                      <Suspense
                        fallback={<div className="col-12">Loading...</div>}
                      >
                        <RecapSummary recap={recap || {}} />
                      </Suspense>
                  )
          }
          <div className="col-12">
            {
              usersErrors && <div className="alert alert-danger form-group" role="alert">
                {
                  usersErrors.map((v, k) => (
                    <div className='row' key={k}>
                      <div className="col">
                        Extended Access Denied: { v }
                      </div>
                    </div>
                  ))
                }
              </div>
            }
          </div>
          {
            !!users
              && Array.isArray(users)
              && users
                  .map(
                    ({id, last_recap = {}}) =>
                      <Suspense
                        fallback={<div className="col-12">Loading...</div>}
                        key={id}
                      >
                        <RecapSummary id={id} recap={last_recap} />
                      </Suspense>
                  )
          }
        </div>
      </DisplayOrLoading>
    )
  }
}
