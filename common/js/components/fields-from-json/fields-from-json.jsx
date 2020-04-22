import { FieldsFromJson as JsonFields } from 'react-component-templates/components'

import AddressSection       from 'common/js/forms/components/address-section'
import AirportSelectField   from 'common/js/forms/components/airport-select-field'
import ArrayField           from 'common/js/forms/components/array-field'
import BraintreeDropIn      from 'common/js/forms/components/braintree-drop-in'
import CalendarField        from 'common/js/forms/components/calendar-field'
import CreditCardField      from 'common/js/forms/components/credit-card-field'
import CountrySelectField   from 'common/js/forms/components/country-select-field'
import HotelSelectField     from 'common/js/forms/components/hotel-select-field'
import InterestSelectField  from 'common/js/forms/components/interest-select-field'
import MeetingSelectField   from 'common/js/forms/components/meeting-select-field'
import Recaptcha            from 'common/js/components/recaptcha'
import ShirtSizeSelectField from 'common/js/forms/components/shirt-size-select-field'
import SiteSeal             from 'common/js/components/site-seal'
import SportSelectField     from 'common/js/forms/components/sport-select-field'
import StateSelectField     from 'common/js/forms/components/state-select-field'
import VideoSelectField     from 'common/js/forms/components/video-select-field'

export default class FieldsFromJson extends JsonFields {
  static tagNames = {
    ...JsonFields.tagNames,
    AddressSection,
    AirportSelectField,
    ArrayField,
    BraintreeDropIn,
    CalendarField,
    CreditCardField,
    CountrySelectField,
    HotelSelectField,
    InterestSelectField,
    MeetingSelectField,
    Recaptcha,
    ShirtSizeSelectField,
    SiteSeal,
    SportSelectField,
    StateSelectField,
    VideoSelectField,
  }
}
