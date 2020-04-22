import React                      from 'react';
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import AsyncComponent             from 'common/js/components/component/async'
import BusForm                    from 'forms/bus-form'
import BusTravelersForm           from 'forms/bus-travelers-form'

const busesUrl = "/admin/traveling/ground_control/buses"

export default class TravelingGroundControlBusesShowPage extends AsyncComponent {
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
    this.state = { bus: {}, loading: true }
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
  resultKey = () => 'bus'
  url = (id) => `${busesUrl}/${id}.json`
  defaultValue = () => ({ colors: [] })

  afterMountFetch = ({bus: { colors = [], link = '', ...bus }, skipTime = false}) => {
    return this.setStateAsync({
      link,
      teamLink: String(link || '').replace('.pdf', '/teammates.pdf'),
      loading: false,
      bus: bus || {},
      colors: colors || [],
      lastFetch: skipTime ? this.state.lastFetch : +(new Date())
    })
  }

  redirectOrReload = (id) =>
    +id === +(this.id)
      ? this.afterMount()
      : this.props.history.push(`${busesUrl}/${id}`)

  backToIndex = () => this.props.history.push(busesUrl)

  render() {
    return (
      <DisplayOrLoading display={!this.state.loading}>
        {
          this.state.link && (
            <div className="row">
              <div className="col">
                <Link
                  className="btn btn-block btn-info mb-3"
                  to={this.state.link} target='_coach_roster'
                >
                  View as Roster
                </Link>
              </div>
              <div className="col">
                <Link
                  className="btn btn-block btn-info mb-3"
                  to={this.state.teamLink} target='_teammates'
                >
                  View as Teammates List
                </Link>
              </div>
            </div>
          )
        }
        <BusForm
          bus={this.state.bus || {}}
          key={`${this.id}.${this.state.bus.id}.${this.state.bus.name}`}
          onCancel={this.backToIndex}
          onSuccess={this.redirectOrReload}
          colors={this.state.colors}
        >
          <BusTravelersForm
            busId={this.state.bus.id}
            buttonText={`${this.state.bus.color} ${this.state.bus.name} (${this.state.bus.sport_abbr})`}
            key={`${this.id}.${this.state.bus.id}.${this.state.bus.name}.travelers`}
          />
        </BusForm>
      </DisplayOrLoading>
    );
  }
}
