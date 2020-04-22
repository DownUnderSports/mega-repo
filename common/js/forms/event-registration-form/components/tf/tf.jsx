import React, { Component } from 'react'
import { TextField } from 'react-component-templates/form-components';
import { DisplayOrLoading } from 'react-component-templates/components';
import { Objected } from 'react-component-templates/helpers';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import CheckboxGroup from 'common/js/forms/components/checkbox-group'

import quickSort from 'common/js/helpers/quick-sort'

import availableEvents from 'common/assets/json/events'
import availableRelays from 'common/assets/json/relays'

import EventList from './event-list'

export default class TFEventRegistrationForm extends Component {
  state = { completed: false, submitting: false }

  get user() {
    return this.parentProps.user || {}
  }

  get parentForm() {
    return this.props.parent || {state: {}, props: {}}
  }

  get parentState() {
    return this.parentForm.state || {}
  }

  get parentProps() {
    return this.parentForm.props || {}
  }

  constructor(props) {
    super(props)
    this.state = {
      showFullList: false,
      selectedCount: 0,
      pristine: true,
      submitting: false,
    }
  }

  componentDidMount() {
    this.parentForm.onChange('sport_id', this.parentForm.sportMappings['TF'])
  }

  onSubmit = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()
    console.log(this)
    this.setState({ submitting: true }, () => {
      const {events = {}, relays = {}} = this.state
      this.runSubmit({
        events,
        relays
      })
    })
  }

  runSubmit = async ({ events = {}, relays = {} }) => {
    try{
      if(!(this.state.selectedCount)) throw new Error('Must select at least one event')
      if(this.props.sample) throw new Error('Cannot submit sample registration')

      const event_registration = {
      }

      let totalCount = 0
      for(let event in events) {
        const pEvent = events[event]
        event_registration[`event_${event}`] = pEvent.ages || []
        totalCount = totalCount + pEvent.ages.length

        if(event_registration[`event_${event}`].length) {

          event_registration[`event_${event}_time`] = (!(pEvent.time) || /reg/i.test(pEvent.time)) ? 'N/A' : pEvent.time

          event_registration[`event_${event}`] = [...quickSort(event_registration[`event_${event}`])]

        } else {
          delete(event_registration[`event_${event}`])
        }
      }
      if(!totalCount) throw new Error('You must register for at least 1 event')

      if(totalCount > 5) throw new Error('Cannot register for more than 5 events')

      for(let relay in relays) {
        if(relays[relay]) event_registration[relay] = /^\d/i.test(relays[relay]) ? relays[relay] : 'N/A'
      }

      const result =  await fetch(`/api/event_registrations/${this.parentProps.id}`, {
        method: 'PUT',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ event_registration })
      });

      const { message, errors = [] } = await result.json()

      if(message === 'ok') {
        return this.setState({ submitting: false, completed: true }, () => {
          this.props.onSuccess && setTimeout(this.props.onSuccess, 2000)
        })
      } else return this.setState({errors, submitting: false})
    } catch(e) {
      console.log(e)
      try {
        document.getElementById('eventRegErrorWrapper').scrollIntoView({behavior: 'smooth'})
      } catch (e) {
        console.log('Bad Browser!')
      }

      this.setState({
        submitting: false,
        errors: [ e.toString() ]
      })
    }
  }

  filterAge = (ev = {}) => {
    if(!ev.all && (!ev[this.user.gender] || !ev[this.user.gender].length)) return []

    const groups = ev.all ? [
      [14, 15],
      [16, 17],
      [18, 19],
      [20]
    ] : ev[this.user.gender]
    return groups.filter((group) => !group[1] || (this.user.age_this_year && (this.user.age_this_year <= group[1])))
  }

  onChange = (ev) => {
    const currentTarget = ev.currentTarget,
          name = currentTarget.name,
          value = currentTarget.value,
          eventOrRelay = /^events/.test(name || '') ? 'events' : 'relays',
          obj = Objected.deepClone(this.state[eventOrRelay] || {}),
          [m, event, category] = name.match(new RegExp(`${eventOrRelay}\\[([^\\[\\]]+)\\](?:\\[([^\\[\\]]+)\\])?`)),
          newState = {pristine: false, [eventOrRelay]: {...obj, [event]: category ? {...(obj[event] || {}), [category]: value } : value }}


    if(category === 'ages') {
      newState.selectedCount = (this.state.selectedCount || 0) - ((obj[event] || {}).ages || []).length + (value || []).length
    }
    console.log(m, event, category, newState)

    this.setState(newState)
  }

  /*
  <div className="list-group-item wide-label">
    <div className="row form-group">
      <div className="col-md-6 form-group">
        <a
          href={trackEventTermsPdf}
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-primary btn-block"
        >
          Review Track Meet Rules
        </a>
      </div>
      <div className="col-md-6 form-group">
        <a
          href={trackEventTimetablePdf}
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-primary btn-block"
        >
          Review Event Timetable
        </a>
      </div>
    </div>
  </div>
  */

  render() {
    const {errors, pristine, submitting} = this.state;

    return this.state.completed ? (
      <div className="list-group-item">
        <div className="mt-3 alert alert-success" role="alert">
          Event Registration Successfully Submitted
        </div>
      </div>
    ) : (
      <DisplayOrLoading
        display={!this.state.submitting}
        loadingElement={
          <JellyBox className="page-loader" />
        }
      >
        <section>
          <div className="list-group-item wide-label text-center">
            <h3>
              You can pick up to 5 event/age group combinations, plus relays
            </h3>
            <h5>
              Ages are calculated as of December 31<sup>st</sup>, 2020
            </h5>
          </div>
          <div className="list-group-item wide-label">
            <p className="text-center">
              To register for an event, click the age group(s) you want to enter for that event, and enter your best time.<br/>
              <u>
                If you have never competed in an event, leave your best time blank. <strong>PLEASE DO NOT GUESS</strong>
              </u>
              <br/> <br/>
              Selected age groups will appear in blue.<br/>
            </p>
          </div>
          <div id="eventRegErrorWrapper"></div>
          {
            errors && errors.length && (
              <div className="list-group-item wide-label">
                {
                  this.state.errors.map((err, i) => (
                    <div key={i} className="mt-3 alert alert-danger" role="alert">
                      { err }
                    </div>
                  ))
                }
              </div>
            )
          }
          <div className="list-group-item wide-label">
            <form
              action={this.action}
              method='post'
              className='edit-package-form'
              onSubmit={this.onSubmit}
            >
              {
                ['running', 'jumping', 'throwing'].map((evType, tdx) => (<div key={tdx} className='row'>
                  <div className="col-12">
                    <h3 style={{margin: '17px', textAlign: 'center'}}>
                      {evType.capitalize()} Events
                    </h3>
                  </div>
                  {
                    availableEvents[evType].map((event, edx) => {
                      const groups = this.filterAge(event)
                      if(!groups.length) return null

                      const evName = event.event.replace().underscore()

                      return (<div key={`${tdx}.${edx}`} className="col-12 col-lg-6 form-group">
                        <label htmlFor={`events.${event.event.replace().underscore()}.time`} className='form-control-label form-group'>
                          <strong>
                            {event.event}
                          </strong>
                        </label>
                        {
                          (event.all || event[this.user.gender].length) && (
                            <CheckboxGroup
                              name={`events[${evName}][ages]`}
                              id={`events_${evName}_ages`}
                              className="float-right"
                              label={
                                <span style={{marginRight: '1rem'}}>
                                  <strong>
                                    Age:&nbsp;
                                  </strong>
                                </span>
                              }
                              options={
                                groups.map((e) =>({
                                  label: `${e[0]}${e[1] ? `/${e[1]}` : '+'}`,
                                  value: `${e[0]}${e[1] ? `/${e[1]}` : '+'}`
                                }))
                              }
                              onChange={this.onChange}
                              clicked={ (el, label) => !(el.checked && this.state.selectedCount > 4) }
                              onError={ (el, label) => {
                                alert(`You have already selected 5 events. You must remove an event before you can add the ${event.event} - ${label.titleize()} Age Group.`)
                              }}
                              value={((this.state.events || {})[evName] || {}).ages || []}
                            />
                          )
                        }
                        <TextField
                          name={`events[${evName}][time]`}
                          onChange={this.onChange}
                          value={((this.state.events || {})[evName] || {}).time || ''}
                          className='form-control'
                          autoComplete={`event ${evName}`}
                          placeholder={`(Best ${evType === 'running' ? 'Time' : evType.replace(/ing/, '').capitalize()})`}
                          looseCasing
                          skipExtras
                        />
                        {event.competency && (
                          <div className="text-danger text-right">
                            <strong>
                              <i>
                                certificate of competency required {
                                  (/vault/i).test(event.event) && (
                                    <div>
                                      additional rental fees
                                    </div>
                                  )
                                }
                              </i>
                            </strong>
                          </div>
                        )}
                      </div>)
                    })
                  }
                </div>))
              }
              <hr/>
              <h3 className="text-center">
                Relays
              </h3>
              <p>
                Listed below are the 2 relays available at this year&apos;s Track &amp; Field meet. <br/>
                If you would like to run in either/both of these relays, <strong>enter your best &ldquo;<u><i>Open</i></u>&rdquo; Time (not split time) for that relay leg</strong>. Again, if you have never competed in either distance, put &ldquo;<strong>REGISTER</strong>&rdquo; if you would like to enter.
              </p>
              <div className="row form-group">
                {
                  Object.keys(availableRelays).map((k,i) => (
                    <div className="col-md-6 form-group" key={i}>
                      <TextField
                        name={`relays[${k}]`}
                        label={<strong>{availableRelays[k]}</strong>}
                        onChange={this.onChange}
                        value={(this.state.relays || {})[k] || ''}
                        className='form-control'
                        autoComplete={`relay ${k}`}
                        placeholder='HH:MM:SS.ms'
                        pattern="(\d{2}:)*\d+(\.\d+)|REGISTER"
                        looseCasing
                      />
                    </div>
                  ))
                }
              </div>
              <button disabled={submitting || pristine} type='submit' className='btn btn-success btn-block'>Submit</button>
            </form>
          </div>
          <div className="list-group-item wide-label">
            {
              (this.state.showFullList && <EventList />) || (<button type="button" className="btn btn-block btn-info" onClick={() => this.setState({showFullList: !this.state.showFullList})}>
                Show Full Event List
              </button>)
            }
          </div>
        </section>
      </DisplayOrLoading>
    )
  }
}
