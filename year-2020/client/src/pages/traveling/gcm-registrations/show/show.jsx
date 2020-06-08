import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import GCMRegistrationForm from 'forms/gcm-registration-form'
import dateFns from 'date-fns'
import CopyClip from 'common/js/helpers/copy-clip'

const gcmRegistrationsUrl = '/admin/traveling/gcm_registrations'

export default class GCMRegistrationsShowPage extends AsyncComponent {
  constructor(props) {
    super(props)
    this.state = { gcm_registration: {}, loading: true }
  }

  mainKey = () => ((this.props.match && this.props.match.params) || {}).id
  resultKey = () => 'gcm_registration'
  url = (id) => `${gcmRegistrationsUrl}/${id}.json`
  defaultValue = () => ({})

  afterFetch = ({gcm_registration, skipTime = false}) => this.setStateAsync({
    loading: false,
    gcm_registration: gcm_registration || {},
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  getGCMFormValues = () => {
    const v = this.state.gcm_registration || {}
    return {
      MainContent_FirstName:         v.first,
      MainContent_LastName:          v.last,
      MainContent_DateOfBirth:       dateFns.format(v.birth_date || Date.new(), 'DD-MM-YYYY'),
      MainContent_GenderID:          (/f/i).test(v.gender) ? 1 : 2,
      MainContent_Email:             'gcm-registrations@downundersports.com',
      MainContent_EmailConfirmation: 'gcm-registrations@downundersports.com',
      MainContent_PostalAddress:     '1755 N 400 E Ste 201',
      MainContent_SuburbTown:        'North Logan',
      MainContent_StateID:           999,
      MainContent_StateText:         'Utah',
      MainContent_PostCode:          '84341',
      MainContent_CountryID:         3,
      MainContent_NationalityID:     3,
      MainContent_MobilePhone:       '0422498358',
      MainContent_EmergencyName:     'Nelson Lage',
      MainContent_EmergencyPhone:    '0422498358',
      MainContent_TandCAccept:       'on',
      dusShirtSize:                  v.shirt_size || '',
    }
  }

  fields = [
    'MainContent_FirstName',
    'MainContent_LastName',
    'MainContent_DateOfBirth',
    'MainContent_GenderID',
    'MainContent_Email',
    'MainContent_EmailConfirmation',
    'MainContent_PostalAddress',
    'MainContent_SuburbTown',
    'MainContent_StateID',
    'MainContent_StateText',
    'MainContent_PostCode',
    'MainContent_CountryID',
    'MainContent_NationalityID',
    'MainContent_MobilePhone',
    'MainContent_EmergencyName',
    'MainContent_EmergencyPhone',
    'MainContent_TandCAccept',
  ]

  openGCM = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()

    CopyClip.unprompted(JSON.stringify({
      values: this.getGCMFormValues(),
      fields: this.fields
    }))
    window.open('https://entergcm.com/','_gcm_registration')
  }

  onSuccess = () => this.props.history.push(gcmRegistrationsUrl)

  render() {
    const {
      gcm_registration: {
        dus_id,
        first,
        middle,
        last,
        suffix,
        gender,
        birth_date,
        category_title,
        shirt_size,
        get_passport,
        cancel_date,
        first_payment_date,
        total_payments,
        team_name,
        address,
        marathon_registration_attributes = {}
      },
    } = this.state || {}
    // // { match: { path, params: { id } }, location: { pathname } } = this.props,
    // url = path.replace(/:id(\(.*?\))?/, `${id}`)

    return (
      <div key={dus_id} className="GCMRegistrations ShowPage">
        <section className='gcm_registration-pages-wrapper' id='gcm_registration-pages-wrapper'>
          <header>
            <h3>
              GCM Registration for {first} {last} ({dus_id})
            </h3>
          </header>
          <div className='row'>
            <div className="col-md-6 col-xs-12">
              <table className="table spread-cells">
                <tbody>
                  <tr>
                    <th>First:</th>
                    <td>{ first }</td>
                  </tr>
                  <tr>
                    <th>Middle:</th>
                    <td>{ middle }</td>
                  </tr>
                  <tr>
                    <th>Last:</th>
                    <td>{ last }</td>
                  </tr>
                  <tr>
                    <th>Suffix:</th>
                    <td>{ suffix }</td>
                  </tr>
                  <tr>
                    <th>Gender:</th>
                    <td>{ gender }</td>
                  </tr>
                  <tr>
                    <th>DOB (YYYY-MM-DD):</th>
                    <td>{ birth_date }</td>
                  </tr>
                  <tr>
                    <th>Category:</th>
                    <td>{ category_title }</td>
                  </tr>
                  <tr>
                    <th>Shirt Size:</th>
                    <td>{ shirt_size }</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div className="col-md-6 col-xs-12">
              <table className="table spread-cells">
                <tbody>
                  <tr>
                    <th>Passport:</th>
                    <td>
                      {
                        get_passport ? (
                          <a href={get_passport} target="_passport" rel="noopener noreferrer">
                            View Passport
                          </a>
                        ) : (
                          <span className='text-danger'>
                            Passport Not Submitted...
                          </span>
                        )
                      }
                    </td>
                  </tr>
                  <tr>
                    <th>First Payment:</th>
                    <td>{ first_payment_date }</td>
                  </tr>
                  <tr>
                    <th>Total Paid:</th>
                    <td>{ total_payments }</td>
                  </tr>
                  <tr>
                    <th>Team:</th>
                    <td>{ team_name }</td>
                  </tr>
                  <tr>
                    <th>Cancel Date:</th>
                    <td>{ cancel_date }</td>
                  </tr>
                  <tr>
                    <th>Address:</th>
                    <td>
                      {
                        address && (
                          <address>
                            { address.split("\n").map((line, i) => <span key={line}>{i && <br/>}{line}</span>) }
                            <br/>USA
                          </address>
                        )
                      }
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div className="col-12 my-5">
              <button
                type="button"
                className="btn btn-block btn-info"
                onClick={this.openGCM}
              >
                Copy Values to Clipboard and open GCM Registration
              </button>
            </div>
            <div className="col-12 my-5">
              <GCMRegistrationForm
                key={
                  `${dus_id}.${
                    (marathon_registration_attributes || {}).id
                  }`
                }
                onSuccess={this.onSuccess}
                registration={marathon_registration_attributes || {}}
                userId={dus_id}
              />
            </div>
          </div>
        </section>
      </div>
    );
  }
}
