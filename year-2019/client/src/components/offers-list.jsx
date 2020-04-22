import React, { Component } from 'react'
import { CardSection, Link } from 'react-component-templates/components';

export default class OffersList extends Component {
  constructor(props) {
    super(props)
    const { offers = [] } = (this.props || {})
    this.state = { offers }
  }
  componentDidUpdate({offers}) {
    if(offers.length && offers !== this.props.offers) {
      this.setState({
        offers: offers
      })
    }
  }

  render() {
    const { url = '/admin/offers/:offer_id' } = (this.props || {})
    const { offers = [] } = (this.state || {})

    return (
      <div className="row">
        {
          offers.map(({
            id: offerId,
            rule: nextRule,
            dus_id,
            user,
            assigner,
            name,
            description,
            amount,
            minimum,
            maximum,
            expiration_date,
            rules,
            add_date,
          }, i) => (
            <div
              key={i}
              className="col-12 col-md-4 form-group"
            >
              <CardSection
                className='mb-3 clickable'
                label={`${nextRule} Offer: ${name}`}
                contentProps={{className: 'list-group'}}
                onClick={() => !this.state[offerId] && this.setState({[offerId]: !this.state[offerId]})}
              >
                <div className="list-group-item p-0">
                  {
                    this.state[offerId] ? (
                      <div className="row">
                        <div className="col-12">
                          <table className="table table-striped mb-0 border-0">
                            <tbody>
                              <tr>
                                <th className="border-bottom-0 border-right">
                                  Name
                                </th>
                                <td>
                                  {name}
                                </td>
                              </tr>
                              <tr>
                                <th className="border-bottom-0 border-right">
                                  Description
                                </th>
                                <td>
                                  {description}
                                </td>
                              </tr>
                              <tr>
                                <th className="border-bottom-0 border-right">
                                  Amount
                                </th>
                                <td>
                                  {amount.str_pretty}
                                </td>
                              </tr>
                              <tr>
                                <th className="border-bottom-0 border-right">
                                  Minimum
                                </th>
                                <td>
                                  {minimum.str_pretty}
                                </td>
                              </tr>
                              <tr>
                                <th className="border-bottom-0 border-right">
                                  Maximum
                                </th>
                                <td>
                                  {minimum.str_pretty}
                                </td>
                              </tr>
                              <tr>
                                <th className="border-bottom-0 border-right">
                                  Expiration Date
                                </th>
                                <td>
                                  {expiration_date}
                                </td>
                              </tr>
                              <tr>
                                <th className="border-bottom-0 border-right">
                                  Rules List
                                </th>
                                <td>
                                  ---------------
                                </td>
                              </tr>
                              {
                                (rules || []).map((rule, r) => (
                                  <tr key={r}>
                                    <td>
                                    </td>
                                    <td>
                                      {rule}
                                    </td>
                                  </tr>
                                ))
                              }
                            </tbody>
                          </table>
                          <hr/>
                          <Link to={url.replace(':offer_id', offerId)} className="btn btn-block btn-sm btn-secondary rounded-0 rounded-bottom">
                            Edit Offer
                          </Link>
                        </div>
                      </div>
                    ) : (
                      <div className="col">
                        <div className='row'>
                          <div className="col-12 border-bottom">
                            <div className='row bg-secondary text-light'>
                              <div className='col-3 border-right'>{amount.str_pretty}</div>
                              <div className='col border-left'>{ name } - {assigner}</div>
                            </div>
                          </div>
                          <div className="col-12 bg-dark text-white">
                            {description}
                          </div>
                        </div>
                      </div>
                    )
                  }
                </div>
              </CardSection>
            </div>
          ))
        }
      </div>
    )
  }
}
