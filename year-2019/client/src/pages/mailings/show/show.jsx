import React from 'react';
import AsyncComponent from 'common/js/components/component/async'
import { Link } from 'react-component-templates/components';
import { DisplayOrLoading } from 'react-component-templates/components'
import AddressSection from 'common/js/forms/components/address-section'
//import authFetch from 'common/js/helpers/auth-fetch'
import onFormChange from 'common/js/helpers/on-form-change';
import './show.css'

const mailingsUrl = `/admin/returned_mails/:id.json`

export default class MailingsShowPage extends AsyncComponent {
  constructor(props) {
    super(props)
    this.state = { mailing: {}, loading: true, form: {} }
  }

  afterFetch = ({mailing, form, skipTime = false}) => this.setStateAsync({
    loading: false,
    mailing: mailing || {},
    form: { address: this.mailingToAddress(mailing.address || {}) },
    lastFetch: skipTime ? this.state.lastFetch : +(new Date())
  })

  afterMount = async () => {
    return await this.getMailing()
  }

  mailingToAddress(mailing) {
    return {
      is_foreign: !!mailing.is_foreign,
      street: mailing.street || '',
      street_2: mailing.street_2 || '',
      street_3: mailing.street_3 || '',
      city: mailing.city || '',
      state_id: mailing.state_id || '',
      zip: mailing.zip || '',
      country: mailing.country || '',
    }
  }

  getMailing = async () => {
    if(!this.getIdProp()) return false
    try {
      const result = await fetch(mailingsUrl.replace(':id', this.getIdProp()), {timeout: 5000}),
            mailing = await result.json()
      console.log({mailing, form: { address: this.mailingToAddress(mailing.address || {}) }})

      if(this._isMounted) return await this.afterFetch({mailing})
    } catch(e) {
      console.error(e)
    }
    return true
  }

  getIdProp = () => {
    return ((this.props.match && this.props.match.params) || {}).id
  }

  submitFailures = async (mailing) => {
    await this.setStateAsync({loading: true})

    const result = await fetch(mailingsUrl.replace(':id', this.state.mailing.id), {
            method: 'PATCH',
            headers: {
              "Content-Type": "application/json; charset=utf-8"
            },
            body: JSON.stringify({
              id: this.state.mailing.id,
              mailing
            })
          })

    await result.json()

    await this.getMailing()
  }

  confirmFailures = async (props) => {

    const result = await fetch(`${mailingsUrl.replace(':id', this.getIdProp())}?effects=${Object.keys(props)[0]}`),
          effects = await result.json()

     if(window.confirm(`Are you SURE? this will affect up to ${effects.count || 0} records`)) {
       await this.submitFailures(props)
     }
  }

  toggleFailed = async () => await this.submitFailures({ failed: !this.state.mailing.failed })
  badAddress = async () => await this.confirmFailures({ bad_address: true })
  isVacant = async () => await this.confirmFailures({ vacant: true })
  newAddress = async () => await this.confirmFailures({ new_address: this.state.form.address })

  updateAddress = (f, k, v) => {
    return onFormChange(this, k, v, true, ()=>{})
  }

  render() {
    const {
      loading,
      mailing: {
        failed,
        category,
        user_id,
        school_id,
        sent,
      },
      form: {
        address = {}
      }
    } = this.state || {},
    { match: { params: { id } }, } = this.props

    return (
      <div key={id} className="Mailings ShowPage">
        <DisplayOrLoading display={!loading}>
          <h1 className='text-center below-header'>
            <span>
              {category} - {address.state} ({sent})
            </span>
          </h1>
          <section className='mailing-pages-wrapper' id='mailing-pages-wrapper'>
            <div className="main">
              <Link
                to={`/admin/users/${user_id}`}
                className='btn btn-block form-group btn-secondary'
              >
                View User
              </Link>
              {
                school_id && (
                  <Link
                    to={`/admin/schools/${school_id}`}
                    className='btn btn-block form-group btn-warning'
                  >
                    View School
                  </Link>
                )
              }
              <hr/>
              {
                failed ? (
                  <button
                    onClick={this.toggleFailed}
                    className='btn btn-block form-group btn-success'
                  >
                    Mark Not Failed
                  </button>
                ) : (
                  <div className='row'>
                    <div className='col'>
                      <button
                        onClick={this.toggleFailed}
                        className='btn btn-block form-group btn-danger'
                      >
                        Mark Failed
                      </button>

                      <button
                        onClick={this.badAddress}
                        className='btn btn-block form-group btn-danger'
                      >
                        Mark Undeliverable
                      </button>

                      <button
                        onClick={this.isVacant}
                        className='btn btn-block form-group btn-danger'
                      >
                        Mark Vacant
                      </button>

                      <div className="form-group">
                        <AddressSection
                          label='New Address'
                          values={this.mailingToAddress(address || {})}
                          onChange={this.updateAddress}
                          valuePrefix='address'
                          name='new_address'
                          className='form-group'
                        >
                        <button
                          onClick={this.newAddress}
                          className='btn btn-block form-group btn-danger'
                        >
                          Mark New Address
                        </button>
                        </AddressSection>

                      </div>
                    </div>
                  </div>
                )
              }
            </div>
          </section>
        </DisplayOrLoading>
      </div>
    );
  }
}
