import SportFieldsComponent from './sport-fields-component'

export default class FBFields extends SportFieldsComponent {
  sportAbbr = () => 'FB'
  positions = () => "QB"
  positionTypes = () => "QB, RB, FB, TE, OL, C"
  height = () => true
  weight = () => true
}
