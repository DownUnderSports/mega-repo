import BusTravelersForm from 'forms/bus-travelers-form'

export default class TeamTravelersForm extends BusTravelersForm {
  constructor(props) {
    super(props)

    this.state = {
      loading: false,
      errors: null,
      changed: false,
      dusId: '',
      travelers: []
    }

    this.action = `${
      this.props.url
      || `/admin/traveling/ground_control/competing_teams/${this.props.competingTeamId}/team_travelers`
    }`
  }

  label = "Enter DUS ID to add a new traveler to Team"
}
