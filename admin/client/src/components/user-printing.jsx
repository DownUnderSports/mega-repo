import React, { Component } from 'react'
import { CardSection, Link } from 'react-component-templates/components';

export default class UserNotes extends Component {
  printTeammates  = (ev) => this.visitPage(ev, 'teammates')
  printTravelPage = (ev) => this.visitPage(ev, 'travel_page')
  printTravelCard = (ev) => this.visitPage(ev, 'travel_card')

  visitPage(ev, path) {
    ev.stopPropagation()
    ev.preventDefault()

    const w = window.open()
    w.name = '_print_page'
    w.opener = null
    w.referrer = null
    w.location = `${this.props.link}/${path}`
  }

  render() {
    return (
      <CardSection
        className="mb-3"
        label="Printing"
        contentProps={{className: 'list-group'}}
      >
        <div className="list-group-item">
          <Link
            className="btn btn-block btn-primary"
            to='#'
            target='_print_page'
            onClick={this.printTravelPage}
          >
            Travel Page
          </Link>
        </div>
        <div className="list-group-item">
          <Link
            className="btn btn-block btn-primary"
            to='#'
            target='_print_page'
            onClick={this.printTravelCard}
          >
            Travel Card
          </Link>
        </div>
        <div className="list-group-item">
          <Link
            className="btn btn-block btn-primary"
            to='#'
            target='_print_page'
            onClick={this.printTeammates}
          >
            Teammates
          </Link>
        </div>
      </CardSection>
    )
  }
}
