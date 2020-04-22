import React                from 'react';
import { DisplayOrLoading } from 'react-component-templates/components';
import AsyncComponent       from 'common/js/components/component/async'
import ScheduleForm         from 'forms/schedule-form'
import TicketForm           from 'forms/ticket-form'

const schedulesUrl = "/admin/traveling/flights/schedules"

export default class TravelingFlightsSchedulesShowPage extends AsyncComponent {
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
    this.state = { schedule: {}, loading: true }
  }

  componentDidUpdate(prevProps) {
    try {
      const { match: { params: { id } } } = prevProps

      if(id !== this.id) this.afterMount()
    } catch(err) {
      this.backToIndex()
    }
  }

  mainKey = () => this.id
  resultKey = () => 'schedule'
  url = (id) => `${schedulesUrl}/${id}.json`
  defaultValue = () => ({})

  afterFetch = ({schedule, skipTime = false}) => this.setStateAsync({
    loading: false,
    schedule: schedule || {},
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  redirectOrReload = (id) =>
    id === this.id
      ? this.afterMount()
      : this.props.history.push(`${schedulesUrl}/${id}`)

  backToIndex = () => this.props.history.push(schedulesUrl)

  render() {
    console.log(this.id)
    return (
      <DisplayOrLoading key={this.id} display={!this.state.loading}>
        <ScheduleForm
          schedule={this.state.schedule || {}}
          key={`${this.id}.${this.state.schedule.id}.${this.state.schedule.pnr}`}
          onCancel={this.backToIndex}
          onSuccess={this.redirectOrReload}
        >
          <TicketForm
            scheduleId={this.state.schedule.id}
            schedulePNR={this.state.schedule.pnr}
            key={`${this.id}.${this.state.schedule.id}.${this.state.schedule.pnr}.tickets`}
          />
        </ScheduleForm>
      </DisplayOrLoading>
    );
  }
}
