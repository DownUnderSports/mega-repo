import React from 'react';
import Component from 'common/js/components/component'
import SchoolInfo from 'components/school-info'
import CopyClip from 'common/js/helpers/copy-clip'
import './show.css'

const schoolsUrl = '/admin/schools/:id.json'

export default class SchoolsShowPage extends Component {
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
        location
      },
    } = this.state || {school: {}}
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
          </span> - {name} ({location})
          </span>
        </h1>
        <section className='school-pages-wrapper' id='school-pages-wrapper'>
          <SchoolInfo
            id={this.mainKey()}
            afterFetch={this.afterFetch}
          />
        </section>
      </div>
    );
  }
}
