import React, { Component } from 'react'
import { CardSection, Link } from 'react-component-templates/components';

export default class DebitsList extends Component {
  render() {
    const { debits = [], url = '/admin/debits/:debit_id' } = (this.props || {})

    return (
      <div className="row">
        {
          debits.map(({
            amount,
            assigner,
            base_debit,
            description,
            dus_id,
            id: debitId,
            name,
          }, i) => (
            <div key={i} className="col-12 col-md-4 form-group">
              <CardSection
                className='mb-3'
                label={base_debit.name}
                contentProps={{className: 'list-group'}}
              >
                <div className="list-group-item p-0">
                  <Link to={url.replace(':debit_id', debitId)}>
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
