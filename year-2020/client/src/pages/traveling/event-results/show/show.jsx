import React                 from 'react';
import { CardSection, DisplayOrLoading }  from 'react-component-templates/components';
import AsyncComponent        from 'common/js/components/component/async'
import EventResultForm       from 'forms/event-result-form'
import EventResultUploadForm from 'forms/event-result-upload-form'

const eventResultsUrl = "/admin/traveling/event_results"

export default class TravelingEventResultsShowPage extends AsyncComponent {
  get id(){
    try {
      const { match: { params: { id } } } = this.props
      return id
    } catch(_) {
      return 'new'
    }
  }

  constructor(props) {
    super(props)
    this.state = { eventResult: {}, loading: true }
  }

  componentDidUpdate(prevProps) {
    try {
      const { match: { params: { id } } } = prevProps
      if(!+id && (id !== "new")) throw new Error("Invalid ID")

      if(id !== this.id) this.afterMount()
    } catch(_) {
      this.backToIndex()
    }
  }

  mainKey = () => this.id
  resultKey = () => 'eventResult'
  url = (id) => `${eventResultsUrl}/${id}.json`
  defaultValue = () => ({ eventResult: {} })

  afterMountFetch = ({eventResult, skipTime = false}) =>
    this.setStateAsync({
      loading: false,
      eventResult: eventResult || {},
      lastFetch: skipTime ? this.state.lastFetch : +(new Date())
    })

  redirectOrReload = (id) =>
    +id === +(this.id)
      ? this.setState({eventResult: {}}, this.afterMount)
      : this.props.history.push(`${eventResultsUrl}/${id}`)

  backToIndex = () => this.props.history.push(eventResultsUrl)

  render() {
    return (
      <DisplayOrLoading key={this.id} display={!this.state.loading}>
        <EventResultForm
          eventResult={this.state.eventResult || {}}
          key={`${this.id}.${this.state.eventResult.id}.${this.state.eventResult.name}.${this.state.eventResult.sport_id}`}
          onCancel={this.backToIndex}
          onSuccess={this.redirectOrReload}
        >
          <CardSection
            className="mb-3"
            label="Static Files"
            contentProps={{className: 'list-group'}}
          >
            {
              (this.state.eventResult.static_ids || []).map(id => (
                <EventResultUploadForm
                  eventId={this.state.eventResult.id}
                  id={id}
                  key={`${this.id}.${this.state.eventResult.id}.${id}`}
                />
              ))
            }
            <EventResultUploadForm
             eventId={this.state.eventResult.id}
            />
          </CardSection>
        </EventResultForm>
      </DisplayOrLoading>
    );
  }
}
