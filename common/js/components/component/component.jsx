import { Component as ReactComponent } from 'react';
//import authFetch from 'common/js/helpers/auth-fetch'

export default class Component extends ReactComponent {
  static async fetchResource(context, url, options = {}, resultKey = false, defaultValue = {}){
    try {
      context.abortIfNeeded()
      context._fetchingResource = fetch(url, options)
      const result = await context._fetchingResource,
            retrieved = await result.json()

      return (resultKey ? retrieved[resultKey] : retrieved) || defaultValue
    } catch(e) {
      console.error(e, url, resultKey, defaultValue)
      return defaultValue
    }
  }

  componentDidMount() {
    this._isMounted = true
  }

  componentWillUnmount() {
    this.abortIfNeeded()
    this._isMounted = false
  }

  abortIfNeeded = () => {
    if(this._fetchingResource) this._fetchingResource.abort()
  }

  setStateAsync = (newState) => new Promise((res) => {
    this.setState(newState, () => res(this.state))
  })

  fetchResource = (...args) => Component.fetchResource(this, ...args)
}
