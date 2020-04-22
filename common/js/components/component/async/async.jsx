import React, { Children, isValidElement, cloneElement } from 'react';
import Component from 'common/js/components/component';
import { DisplayOrLoading } from 'react-component-templates/components'
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'


export default class AsyncComponent extends Component {
  constructor(props) {
    super(props)
    this.state = { loading: true }
  }

  async componentDidMount() {
    this.runComponentDidMount()
    return await this.afterMount()
  }

  async componentWillUnmount() {
    this.runComponentWillUnmount()
    return await this.beforeUnmount()
  }

  runComponentDidMount() {
    Component.prototype.componentDidMount.call(this)
  }

  runComponentWillUnmount() {
    Component.prototype.componentWillUnmount.call(this)
  }


  afterMount = async () => {
    if(!this._isMounted) return false
    if(!this.isCollection && !this.mainKey()) return false
    await this.setStateAsync({ loading: true })
    let result = await this.fetchResource(this.url(this.mainKey()), this.fetchOptions(), this.valueKey(), this.defaultValue()),
        k = this.resultKey()

    if(this._isMounted) {
      if(k) result = { [k]: result }
      if(this.afterMountFetch) {
        return await this.afterMountFetch({
          loading: false,
          ...result
        })
      } else {
        return await this.setStateAsync({
          loading: false,
          ...result
        })
      }
    }
    return false
  }

  beforeUnmount = async () => true

  baseState = () => ({})
  mainKey = () => this.props.mainKey
  url = () => this.props.url
  fetchOptions = () => ({timeout: 5000})
  resultKey = () => this.props.valueKey
  valueKey = () => this.props.valueKey
  defaultValue = () => this.props.defaultValue
  childProps = (child) => isValidElement(child) ? cloneElement(child, { resourceState: this.state }) : child

  render() {
    return (
      <DisplayOrLoading
        display={!this.state.loading}
        message='LOADING...'
        loadingElement={
          <JellyBox className="page-loader" />
        }
      >
        {
          Children.map(this.props.children, this.childProps)
        }
      </DisplayOrLoading>
    )
  }
}
