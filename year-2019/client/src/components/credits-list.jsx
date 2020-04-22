import React, { Component } from 'react'
import { CardSection, Link } from 'react-component-templates/components';

export default class CreditsList extends Component {
  render() {
    const { credits = [], url = '/admin/credits/:credit_id' } = (this.props || {})

    return (
      <div className="row">
        {
          credits.map(({
            amount,
            assigner,
            description,
            dus_id,
            id: creditId,
            name,
          }, i) => (
            <div key={i} className="col-12 col-md-4 form-group">
              <CardSection
                className='mb-3'
                label={name}
                contentProps={{className: 'list-group'}}
              >
                <div className="list-group-item p-0">
                  <Link to={url.replace(':credit_id', creditId)}>
                    <div className="col">
                      <div className="row">
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
                  </Link>
                </div>
              </CardSection>
            </div>
          ))
        }
      </div>
    )
  }
}
