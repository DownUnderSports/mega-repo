import SportFieldsComponent from './sport-fields-component'

export default class FBFields extends SportFieldsComponent {
  sportAbbr = () => 'VB'
  positions = () => "OH"
  positionTypes = () => "OH, MB, RH, O, MH, L"
  height = () => true
  weight = () => false
}
