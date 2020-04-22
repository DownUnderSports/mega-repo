import React from 'react';
import Component from 'common/js/components/component'
//import authFetch from 'common/js/helpers/auth-fetch'
import { debounce } from 'react-component-templates/helpers'
import { TextField } from 'react-component-templates/form-components';
import dusIdFormat from 'common/js/helpers/dus-id-format'
import withRedirect from 'common/js/helpers/with-redirect'


export function isValidUrl(id) {
  return `/api/users/${id}/valid`
}

export function isTravelerUrl(id) {
  return `/api/users/${id}/traveling`
}

export function getUserNameUrl(id) {
  return `/api/users/${id}`
}

export const userIsValid = async (dusId, context = {}) => {
  context = context || {}

  if(dusId && ((dusId = dusIdFormat(String(dusId))).length === 7)) {
    try {
      const preset = Number(sessionStorage.getItem(dusId))
      if(preset) return preset
    } catch(_) {}

    try {
      context._fetchable = fetch(isTravelerUrl(dusId))
      await context._fetchable
      try {
        sessionStorage.setItem(dusIdFormat(String(dusId)), 2)
      } catch(_) {}
      return 2
    } catch(e) {
      if(e.response) {
        const value = (e.response.status === 410) ? 1 : 0
        try {
          value && sessionStorage.setItem(dusIdFormat(String(dusId)), value)
        } catch(_) {}
        return value
      } else {
        console.error(e)
        throw e
      }
    }
  }
  return false
}

export const getUserName = async (dusId, context = {}) => {
  context = context || {}

  if(dusId && ((dusId = dusIdFormat(dusId)).length === 7)) {
    try {
      const preset = sessionStorage.getItem(`${dusId}-username`)
      if(preset) return preset
    } catch(_) {}

    try {
      context._fetchable = fetch(getUserNameUrl(dusId))
      const result = await context._fetchable,
            json = await result.json()

      try {
        json.print_names && sessionStorage.setItem(`${dusId}-username`, json.print_names)
      } catch(_) {}

      return json.print_names
    } catch(e) {
      return 'Not Found'
    }
  }
  return ''
}

export const baseErrorLink = "mailto:it@downundersports.com?subject=Error%20In%20User%20Lookup&body=%0A%0APAGE%20ERROR%3A%20|PAGE_ERROR|%0A%0AUSER%20AGENT%3A%20|USER_AGENT|%0A%0ACONSOLE%3A%20%5B%5D"

class FindUser extends Component {
  state = { invalid: false, error: false }

  get emailErrorLink() {
    let link = baseErrorLink.replace('|PAGE_ERROR|', encodeURIComponent(this.state.error || '')).replace('|USER_AGENT|', encodeURIComponent((window.navigator || {}).userAgent))
    try {
      let linkWithHistory = link.replace(/CONSOLE%3A%20.*/, encodeURIComponent('CONSOLE: ' + JSON.stringify((console.history || [])[0])))
      link = linkWithHistory
    } catch (e) {
      console.log(e)
    }
    return link || "mailto:it@downundersports.com"
  }


  constructor(props) {
    super(props)
    this.userValid = debounce(this.userValid, 150)
  }

  componentDidMount = () => {
    if(this.props.dusId) this.userValid(this.props.dusId)
  }

  componentWillUnmount() {
    this.abortFetch()
  }

  abortFetch = () => {
    if(this._fetchable) this._fetchable.abort()
  }

  userValid = async (dusId) => {
    this.abortFetch()
    try {
      switch (await userIsValid(dusId, this)) {
        case 2:
          this.props.redirectTo(`${this.props.travelerUrl || this.props.url || ''}/${dusId}${this.props.search || ''}`)
          return true;
        case 1:
          localStorage.setItem(dusIdFormat(String(dusId)), 1)
          this.props.redirectTo(`${this.props.url || ''}/${dusId}${this.props.search || ''}`)
          return true;
        default:
          await this.setStateAsync({ invalid: dusId.length > 6, error: false });
          return false
      }
    } catch(e) {
      await this.setStateAsync({ error: e.toString(), invalid: false });
      return false
    }
  }

  render() {
    return (
      <div className='row'>
        <div className="col-12 form-group">
          <TextField
            name='dus_id'
            label={this.props.label || 'DUS ID'}
            skipExtras={!!this.props.skipExtras}
            onChange={(e) => this.userValid(e.target.value)}
            defaultValue={this.props.dusId ? dusIdFormat(this.props.dusId) : ''}
            caretIgnore='-'
            className='form-control'
            autoComplete='off'
            placeholder='AAA-AAA'
            pattern="[a-zA-Z]*"
            looseCasing
            required
            uncontrolled
          />
          {
            this.props.skipHelper ? '' : (
              <small>
                <ul className="mt-1">
                  <li>
                    Please enter a valid DUS ID to continue
                  </li>
                  <li>
                    The DUS ID links targets a specific person in our database
                  </li>
                  <li>
                    <u>Using someone else's DUS ID will cause or your submission to be linked to the wrong person</u>
                  </li>
                  <li>
                    If you do not know or do not have the correct DUS ID, <a href="tel:+1-435-753-4732">please call</a>/<a href="sms:+1-435-753-4732">text our office</a> @ 435-753-4732 or <a href="mailto:mail@downundersports.com">email us at mail@downundersports.com</a>
                  </li>
                </ul>
              </small>
            )
          }
        </div>
        {
          !this.props.skipHelper && (
            this.state.error ? (
              <div className="col-12 form-group">
                <div className="alert alert-danger text-center" role="alert">
                  <h4 className='text-center'>
                    Uh-Oh! An error occured while attempting to find the user with the submitted DUS ID:
                  </h4>
                  <p>
                    { this.state.error }
                  </p>
                  <a className="alert-link" href={this.emailErrorLink}>Click Here to report this Error</a>
                </div>
              </div>
            ) : (
              this.state.invalid && (
                <div className="col-12 form-group">
                  <div className="alert alert-danger text-center" role="alert">
                    <h4 className='text-center'>
                      Uh-Oh! The submitted ID is not valid.
                    </h4>
                    If you believe you've reached this message in error,&nbsp;
                    <a className="alert-link" href="tel:+1-435-753-4732">please call our office @ 435-753-4732</a><br/>
                    Please be ready to provide information about the browser you are using; e.g. the version, and operating system it is running on.
                  </div>
                </div>
              )
            )
          )
        }
      </div>
    );
  }
}

export default withRedirect(FindUser)
