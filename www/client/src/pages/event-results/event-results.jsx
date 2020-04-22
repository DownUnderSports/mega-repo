import React, { Component } from 'react'
import { CardSection, Link } from 'react-component-templates/components'
export default class EventResultsPage extends Component {
  state = { results: [], isOpen: {} }

  async componentDidMount() {
    await this.getResults()
  }

  getResults = async () => {
    try {
      const { match: { params: { sport } } } = this.props,
            response = await fetch(`/api/event_results/${sport}.json`),
            { results = [] } = await response.json()
      this.setState({ results })
    } catch {
      this.setState({ results: [] })
    }
  }

  toggleFile = (ev) => {
    const id = +ev.currentTarget.dataset.id || 0,
          isOpen = { ...this.state.isOpen }

    isOpen[id] = !isOpen[id]
    this.setState({ isOpen })
  }

  render() {
    const results = this.state.results || []

    return <section className="my-5">
      <header>
        <h2>
          View Competition Results
        </h2>
      </header>
      {
        results.length
          ? (this.state.results || []).map(result => (
              <div key={result.id}>
                <hr/>
                <CardSection
                  label={`${result.sport.full_gender}: ${result.name}`}
                  contentProps={ { className: "list-group" } }
                >
                  {
                    (result.static_files || []).map(file => (
                      <div key={file.id} className="list-group-item">
                        <button className="btn btn-info btn-block" data-id={file.id} onClick={this.toggleFile}>
                          { this.state.isOpen[file.id] ? 'Close' : 'View' } { file.name }
                        </button>
                        {
                          !!this.state.isOpen[file.id]
                          && (
                            /\.pdf/.test(file.link) ? (
                              <object
                                data={file.link}
                                width="100%"
                                height="500"
                                type="application/pdf"
                                className="mt-3"
                              >
                                <object
                                  data={`https://docs.google.com/viewer?embedded=true&url=${file.link}`}
                                  width="100%"
                                  height="500"
                                  className="mt-3"
                                >
                                  <Link to={file.attachment_link} className="btn btn-info btn-block btn-warning mt-3">
                                    Your Browser Does Not Support Embedded PDFs, Click Here To Download { file.name }
                                  </Link>
                                </object>
                              </object>
                            ) : (
                              <img
                                className="img-fluid"
                                src={file.link}
                                alt={file.name}
                              />
                            )
                          )
                        }
                        {

                        }
                      </div>
                    ))
                  }
                </CardSection>
              </div>
            ))
          : <div>
              <hr/>
              <p>No Results Available</p>
            </div>
      }
    </section>
  }
}
