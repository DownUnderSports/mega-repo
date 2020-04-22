import SportFieldsComponent from './sport-fields-component'

export default class BBBAndGBBFields extends SportFieldsComponent {
  positions = () => "PG"
  positionTypes = () => "PG, SG, SF, PF, C"
  height = () => true
  weight = () => true
}
