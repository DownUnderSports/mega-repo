import React, { Component, Fragment } from 'react';
import Tooltip from 'common/js/components/tooltip'
import { Interest } from 'common/js/contexts/interest';
import { Objected } from 'react-component-templates/helpers'
// import { SelectField } from 'react-component-templates/form-components';

const interestDescriptions = {
  "traveling": "They are currently an Active Traveler",
  "sending-deposit": "They have told us they will be signing up, but have not yet",
  "interested": "They are interested in going, but are not sure if they will join",
  "curious": "They want more information",
  "unknown": "We do not know how they are leaning",
  "never": "They have told us they will never be interested; We could get into trouble if we attempt contacting them",
  "not-going": "They have told us they are not going THIS year, and we do not know if they are interested in going next year",
  "no-respond": "They are unresponsive after multiple attempts to contact them, do not attempt until they respond",
  "next-year": "They have told us they are not going THIS year, but they want to go next year.",
  "supporter-not-going": "SUPPORTER Not going or Canceled; still contactable as a supporter",
  "open-tryout": "Open Tryout, Has not been confirmed to meet recruiting standards",
}
export default class InterestSelectField extends Component {
  static contextType = Interest.Context

  get body() {
    if(!this._body) this._body = window.document.getElementsByTagName('BODY')[0]

    return this._body
  }

  constructor(props){
    super(props)
    this.state = {
      isOpen: false,
      options: [],
      mapped: {}
    }
  }

  async componentDidMount(){
    try {
      return await (this.context.interestState.loaded ? Promise.resolve() : this.context.interestActions.getInterests()).then(this.mapOptions)
    } catch (e) {
      console.error(e)
    }
  }

  componentDidUpdate() {
    const { loaded = false, options = [] } = this.state
    if(
      (!loaded && this.context.interestState.loaded) ||
      (options.length !== this.context.interestState.ids.length)
    ) {
      this.mapOptions()
    }
  }

  componentWillUnmount() {
    this.removeBodyClicker()
  }

  mapOptions = () => {
    const { interestState: { ids = [], loaded = false }, interestActions: {find = ((v) => v)} } = this.context,
    options = ids.map((id) => find(id)).map(({id, level, contactable}) => ({
      id,
      value: id,
      label: `${level} - ${contactable ? 'Is C' : 'Unc'}ontactable`,
      level,
      tooltip: interestDescriptions[level.toLowerCase().replace(/\s+(-\s*)?/g, '-')]
    })),
    mapped = {}
    for (var i = 0; i < options.length; i++) {
      mapped[options[i].id] = options[i]
    }

    this.setState({
      loaded,
      options,
      mapped
    })
  }

  addBodyClicker = () =>
    this.eventAdded ||
    (
      (this.eventAdded = true) &&
      this.body.addEventListener('mousedown', this.closeOpenSelect)
    )

  removeBodyClicker = () => {
    this.body.removeEventListener('mousedown', this.closeOpenSelect)
    this.eventAdded = false
  }

  closeOpenSelect = (e) => {
    console.log(e.target, this.refs.wrapper.contains(e.target))
    if(!this.refs.wrapper.contains(e.target)) {
      this.removeBodyClicker()
      this.setState({ isOpen: false })
    } else if(this.refs.wrapper.contains(e.currentTarget)) {
      this.onChange(e)
    }
  }

  onBlur = (e) => {
    console.log('blur', e.relatedTarget)
    if(!this.refs.wrapper.contains(e.relatedTarget)) {
      this.setState({ isOpen: false }, this.removeBodyClicker)
    }
  }

  onKeyDown = e => {
    if(e.key === "Enter") this.onChange(e)
    // console.log(e.currentTarget, e.key)
  }

  onChange = e => {
    console.log(e, e.target, e.currentTarget)
    this.props.onChange && this.props.onChange(false, (this.state.mapped[e.currentTarget.dataset.id] || {}))
    this.setState({isOpen: false}, this.removeBodyClicker)
  }

  showInterests = () => this.setState({ isOpen: true }, this.addBodyClicker)

  setInterest = e => {
    const el = e.currentTarget
    console.log(el)
  }

  render() {
    const {label = '', name, id = name, feedback = '', value, viewProps = {}, skipExtras = false} = Objected.filterKeys(this.props, ['autoCompleteKey', 'onChange', 'validator', 'caretIgnore', 'options', 'filterOptions']),
          tabIndex = (+(this.props.tabIndex || 0) < 0) ? -1 : 0,
          { isOpen, options, mapped } = this.state
    // return (
    //   <SelectField
    //     {...Objected.filterKeys(this.props, ['interestState', 'interestActions'])}
    //     options={this.state.options}
    //     filterOptions={{
    //       indexes: [ 'level' ]
    //     }}
    //   />
    // )
    const select = isOpen ? (
      <div
        ref="wrapper"
        onBlur={this.onBlur}
      >
        {
          options.map( (o, i) => (
            <div
              key={o.id}
              onClick={this.onChange}
              className={
                `border clickable position-relative ${
                  (i === 0) ? 'rounded-top' : 'border-top-0'
                } ${
                  (i === (options.length - 1)) && 'rounded-bottom'
                } py-1 px-3`
              }
              // data-tooltip={o.tooltip}
              data-id={o.id}
              data-level={o.level}
              tabIndex={tabIndex}
              onKeyDown={this.onKeyDown}
            >
            <Tooltip
              content={o.tooltip}
            >
              <span className={(value === o.value) ? "text-success" : 'invisible'}>&#10004;</span>
              {o.label}
            </Tooltip>
            </div>
          ))
        }
      </div>
    ) : (
      <div
        ref="wrapper"
        className="form-control clickable"
        // onClick={this.showInterests}
        onFocus={this.showInterests}
        data-tooltip={(mapped[value] || {}).tooltip}
        tabIndex={tabIndex}
        {...viewProps}
      >
        <Tooltip
          content={(mapped[value] || {}).tooltip}
        >
          <input name={name} id={id} type="hidden" />
          {(mapped[value] || {}).label || ''}
        </Tooltip>
      </div>
    )

    return skipExtras ? select : (
      <Fragment>
        <label key={`${id}.label`} htmlFor={id}>{label}</label>
        {
          select
        }
        <small key={`${id}.feedback`} className="form-control-focused">
          {feedback}
        </small>
      </Fragment>
    )
  }
}
