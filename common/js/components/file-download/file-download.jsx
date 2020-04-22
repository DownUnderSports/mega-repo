import React, { Component } from 'react'
import ReactDOM from 'react-dom'
import { string, func, object, oneOfType, arrayOf, node, bool } from 'prop-types'
import { DisplayOrLoading, Link } from 'react-component-templates/components'
import flashMessage from 'common/js/helpers/flash-message'
//import authFetch from 'common/js/helpers/auth-fetch'

export default class FileDownload extends Component {
  state = { downloading: false }

  static propTypes = {
    path: string,
    method: string,
    onComplete: func,
    params: object,
    useForm: bool,
    children: oneOfType([
      arrayOf(node),
      node
    ]).isRequired
  }

  static defaultProps = {
    path: '/',
    method: 'GET',
    params: {},
    useForm: false
  }

  get _formInputs() {
    const { params } = this.props

    return Object.keys(params).map((name, index) => {
      return (
        <input
          key={index}
          name={name}
          type="hidden"
          value={params[name]}
        />
      )
    })
  }

  get _paramString() {
    const { params } = this.props
    let str = ''

    for(let k in params) {
      str = `${str}${k}=${params[k]}`
    }
    return str
  }

  downloadFile = () => {
    this.setState({downloading: this.props.useForm ? 'useForm' : true}, async () => {
      if(this.props.useForm) return true
      try {
        const { method, path } = this.props,
              response = await fetch(`${path}?${this._paramString}`, {
                method: method,
              })
        if(this.props.emailed) {
          const result = await response.json()
          flashMessage(`File ${result.success ? `sent to: ${result.id}` : 'not sent'}`)
        } else {
          const contentDisposition = response.headers.get('content-disposition'),
                blob = await response.blob(),
                url = window.URL.createObjectURL(blob),
                a = document.createElement('a')

          let fileName = (contentDisposition && contentDisposition.match(/filename="(.*)"$/))
          if(fileName) fileName = fileName[1]
          if(!fileName){
            fileName = path.match(/\/?([^/]*)(\?.*)?$/)
            fileName = fileName && fileName[1]
          }

          console.log(contentDisposition, fileName, response.headers)

          a.href = url
          a.download = fileName || `file downloaded from ${path || '/'}`
          document.body.appendChild(a) // we need to append the element to the dom -> otherwise it will not work in firefox
          a.click()
          a.remove()  //afterwards we remove the element again
        }

        this.setState({
          downloading: false
        }, () => {
          this.props.onComplete && this.props.onComplete()
        })
      } catch(e) {
        console.log(e)
        this.setState({
          downloading: false
        })
      }
    })
  }

  setDownload = async (form) => {
    if(!this._form) {
      this._form = form
      try {
        await form.submit()
        this.setState({
          downloading: false
        }, () => {
          this.props.onComplete && this.props.onComplete()
        })
      } catch(e) {
        console.log(e)
      }
    }
  }

  submit() {
    ReactDOM.findDOMNode(this).submit()
  }

  onClick = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    this.downloadFile()
  }

  render() {
    if(this.state.downloading === 'useForm') {
      const {path, method} = this.props

      return (
        <form
          ref={this.setDownload}
          action={path}
          className="hidden"
          method={method}
        >
          {this._formInputs}
        </form>
      )
    } else {
      return (
        <DisplayOrLoading display={!this.state.downloading}>
          <Link to={this.props.path} onClick={this.onClick}>
            {this.props.children}
          </Link>
        </DisplayOrLoading>
      )
    }
  }
}
