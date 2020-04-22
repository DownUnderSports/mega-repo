import React                from 'react';
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import AsyncComponent       from 'common/js/components/component/async'
import CompetingTeamForm              from 'forms/competing-team-form'
import CompetingTeamTravelersForm     from 'forms/team-travelers-form'

const competingTeamsUrl = "/admin/traveling/ground_control/competing_teams"

export default class TravelingGroundControlCompetingTeamsShowPage extends AsyncComponent {
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
    this.state = { competingTeam: {}, loading: true }
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
  resultKey = () => 'competingTeam'
  url = (id) => `${competingTeamsUrl}/${id}.json`
  defaultValue = () => ({ competingTeam: {} })

  afterMountFetch = ({competingTeam: { link = '', ...competingTeam }, skipTime = false}) => {
    return this.setStateAsync({
      link,
      teamLink: String(link || '').replace('.pdf', '/teammates.pdf'),
      loading: false,
      competingTeam: competingTeam || {},
      lastFetch: skipTime ? this.state.lastFetch : +(new Date())
    })
  }

  redirectOrReload = (id) =>
    +id === +(this.id)
      ? this.afterMount()
      : this.props.history.push(`${competingTeamsUrl}/${id}`)

  backToIndex = () => this.props.history.push(competingTeamsUrl)

  render() {
    return (
      <DisplayOrLoading key={this.id} display={!this.state.loading}>
        {
          this.state.link && (
            <div className="row">
              <div className="col">
                <Link
                  className="btn btn-block btn-info mb-3"
                  to={this.state.link} target='_coach_roster'
                >
                  View Roster
                </Link>
              </div>
              <div className="col">
                <Link
                  className="btn btn-block btn-info mb-3"
                  to={this.state.teamLink} target='_teammates'
                >
                  Teammates List
                </Link>
              </div>
            </div>
          )
        }
        <CompetingTeamForm
          competingTeam={this.state.competingTeam || {}}
          key={`${this.id}.${this.state.competingTeam.id}.${this.state.competingTeam.letter}`}
          onCancel={this.backToIndex}
          onSuccess={this.redirectOrReload}
        >
          <CompetingTeamTravelersForm
            competingTeamId={this.state.competingTeam.id}
            buttonText={`${this.state.competingTeam.name} (${this.state.competingTeam.sport_abbr})`}
            key={`${this.id}.${this.state.competingTeam.id}.${this.state.competingTeam.pnr}.travelers`}
          />
        </CompetingTeamForm>
      </DisplayOrLoading>
    );
  }
}
