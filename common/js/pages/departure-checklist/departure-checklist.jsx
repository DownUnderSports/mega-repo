import React from 'react'
import Component from 'common/js/components/component'
import { CardSection, Link } from 'react-component-templates/components';

export default class DepartureChecklistPage extends Component {
  constructor(props){
    super(props)
    this.state = {}
  }

  async componentDidMount(){
    await this.fetchUser()
  }

  fetchUser = async () => {
    const { match: { params: { userId } } } = this.props,
          fetchUrl = `/api/departure_checklists/${userId}`

    if(userId) {
      let val = {}
      try {
        const res = await fetch(fetchUrl)
        val = await res.json() || {}
      } catch(_) {
        val = {}
      }
      return await this.setStateAsync(val)
    }
  }

  showVerified(v) {
    return this.state.verified
      ? v
      : <strong className="text-danger">
          Complete Item(s) Above
        </strong>
  }

  render() {
    return (
      <CardSection
        className="my-5"
        label={<div>
          Departure Checklist
          {this.state.dus_id && `: ${this.state.name} (${this.state.dus_id})`}
        </div>}
        contentProps={{className: 'list-group'}}
      >
        {
          this.state.dus_id ? (
            <>
              <div className="list-group-item">
                <h6 className="text-center text-danger">
                  <strong>
                    <i>
                      As we get closer to departure, more items will be added to the list below. Please check back weekly for any new items.
                    </i>
                  </strong>
                </h6>
              </div>
              <div className="list-group-item">
                Important Info: {
                  this.state.verified && this.state.visa_questions_answered ? (
                    <strong className="text-success">Completed</strong>
                  ) : (
                    <Link to={`/travel-info/${this.props.match.params.userId}`}>
                      Click Here
                    </Link>
                  )
                }
              </div>
              <div className="list-group-item">
                Legal Documents: {
                  this.showVerified(
                    <Link to={`/legal-documents/${this.props.match.params.userId}`}>
                      {
                        this.state.legal
                          ? <strong className="text-success">
                              { this.state.legal }
                            </strong>
                          : 'Click Here'
                      }
                    </Link>
                  )
                }
              </div>
              {
                this.state.athlete && (
                  <>
                    <div className="list-group-item">
                      Uniform Order: {
                        this.showVerified(
                          this.state.uniform_order
                            ? <strong className="text-success">
                                Completed
                              </strong>
                            : <Link to={`/uniform-order/${this.props.match.params.userId}`}>
                                Click Here
                              </Link>
                        )
                      }
                    </div>
                    <div className="list-group-item">
                      Event Registration: {
                        this.showVerified(
                          this.state.registered
                            ? <strong className="text-success">
                                Completed
                              </strong>
                            : <Link to={`/event-registration/${this.props.match.params.userId}`}>
                                Click Here
                              </Link>
                        )
                      }
                    </div>
                  </>
                )
              }
              <div className="list-group-item">
                Passport: {
                  this.showVerified(
                    this.state.passport
                      ? <strong className="text-success">
                          Completed
                        </strong>
                      : <Link to={`/passport/${this.props.match.params.userId}`}>
                          Click Here
                        </Link>
                  )
                }
              </div>
            </>
          ) : (
            <div className="list-group-item">
              Please contact a Down Under Sports representative or view your statement for your departure checklist link.
              <ul>
                <li>Email: <a href="mailto:mail@downundersports.com">mail@downundersports.com</a></li>
                <li>Phone: <a href="tel:435-753-4732">435-753-4732</a></li>
              </ul>
            </div>
          )
        }
      </CardSection>
    );
  }
}
