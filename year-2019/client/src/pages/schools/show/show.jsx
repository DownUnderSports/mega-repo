import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
// import { Route, Switch } from 'react-router-dom';
// import { Link } from 'react-component-templates/components';
import CopyClip from 'common/js/helpers/copy-clip'
import './show.css'

const schoolsUrl = '/admin/schools/:id.json'

export default class SchoolsShowPage extends AsyncComponent {
  constructor(props) {
    super(props)
    this.state = { school: {}, loading: true }
  }

  mainKey = () => ((this.props.match && this.props.match.params) || {}).id
  resultKey = () => 'school'
  url = (id) => schoolsUrl.replace(':id', id)
  defaultValue = () => ({})

  afterFetch = ({school, skipTime = false}) => this.setStateAsync({
    loading: false,
    school: school || {},
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  copyPid = () => {
    const {
      school: {
        pid,
      },
    } = this.state || {}

    CopyClip.prompted(`${pid}`)
  }

  render() {
    const {
      school: {
        pid,
        name,
        allowed,
        allowed_home,
        closed,
        address = {},
      },
    } = this.state || {}
    // // { match: { path, params: { id } }, location: { pathname } } = this.props,
    // url = path.replace(/:id(\(.*?\))?/, `${id}`)

    return (
      <div key={pid} className="Schools ShowPage">
        <h1 className='text-center below-header'>
          <span>
          <span
            className='clickable copyable'
            onClick={this.copyPid}
          >
            { pid }
          </span> - {name} ({address.city}, {address.state_abbr})
          </span>
        </h1>
        <section className='school-pages-wrapper' id='school-pages-wrapper'>
          <div className="main">
            <div className='row'>
              <div className="col">
                {allowed}
              </div>
              <div className="col">
                {allowed_home}
              </div>
              <div className="col">
                {closed}
              </div>
            </div>
          </div>
        </section>
      </div>
    );
  }
}
