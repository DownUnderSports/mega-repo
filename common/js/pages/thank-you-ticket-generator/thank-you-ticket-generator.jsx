import React from 'react'
import Component from 'common/js/components/component'
import { CardSection, Link } from 'react-component-templates/components';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import CopyClip from 'common/js/helpers/copy-clip'
// import eventIsSupported from "common/js/helpers/event-is-supported"
import "./thank-you-ticket-generator.css"
const ticketMessage = "Thank you for supporting me in my journey to compete in Australia! Here is an entry to the Down Under Sports Travel Giveaways:"
export default class ThankYouTicketGeneratorPage extends Component {
  constructor(props){
    super(props)
    this.state = {
    }
  }

  async componentDidMount(){
    // if(eventIsSupported("afterprint")) {
    //   this.printLocal = true
    //   window.addEventListener("afterprint", this.afterPrint)
    // } else if (window.matchMedia) {
    //   this.mediaQueryList = window.matchMedia('print');
    //   this.mediaQueryList.addListener(this.onMediaMatch);
    // }

    await this.fetchUser()
  }

  async componentWillUnmount() {
    // this.printLocal = false
    // this.mediaQueryList && this.mediaQueryList.removeListener(this.onMediaMatch);
    // try {
    //   window.removeEventListener("afterprint", this.afterPrint)
    // } catch(_) {}
  }

  componentDidUpdate({ match = {} }, state) {
    try {
      if(match.params.userId !== this.props.match.params.userId) this._idHash = null
    } catch(_) {
      this._idHash = ''
    }
    if(state.tickets !== this.state.tickets) {
      this._ticketParams = ''
      if(this.state.tickets && this.state.tickets.length > 1) this.downloadPage()
    }
  }

  get idHash() {
    try {
      this._idHash = this._idHash || this.props.match.params.userId
    } catch (_) {
      this._idHash = ''
    }
    return this._idHash
  }

  get ticket() {
    let ticket
    try {
      ticket = this.state.tickets[0] || {}
    } catch (_) {
      ticket = {}
    }
    return ticket
  }

  get ticketLink() {
    return `${ window.location.origin }${ this.ticket.link }`
  }

  get ticketParams() {
    this._ticketParams = this._ticketParams || this.state.tickets.map(ticket => `ids[]=${encodeURIComponent(ticket.id)}`).join("&")
    return this._ticketParams
  }

  // afterPrint = (ev) => {
  //   console.log(ev)
  // }

  // onMediaMatch = (mql) => !mql.matches && this.afterPrint();

  fetchUser = async () => {
    const userId = this.idHash,
          fetchUrl = `/api/users/${userId}/traveling?by_hash=1`

    if(userId) {
      try {
        await fetch(fetchUrl)
        return await this.setStateAsync({ allowed: true })
      } catch(_) {
      }
    }
    return await this.setStateAsync({ allowed: false })
  }

  backToChecklist = () => this.props.history.push(`/departure-checklist/${this.idHash}`)

  downloadPage = () => {
    const ticketParams = this.ticketParams,
          id = `download-tickets-${ticketParams.replace(/[^0-9]/g, "-")}`.replace(/-+/g, "-").replace()
    setTimeout(this.setState({ tickets: null }))
    if(document.getElementById(id)) return false
    const iframe = document.createElement("iframe");
    iframe.id = id
    iframe.src = `/api/generate_thank_you_tickets/${this.idHash}?for_print=1&${this.ticketParams}`
    iframe.title = id
    iframe.classList.add("downloader")
    document.body.appendChild(iframe)
  }

  // renderPage = () =>
  //   <iframe
  //     title="generated-tickets"
  //     id="print-tickets"
  //     src={`/api/generate_thank_you_tickets/${this.idHash}?for_print=1&${this.ticketParams}`}
  //     frameBorder="0"
  //   />

  // <>
  //   <div key="help-text" className="list-group-item">
  //     Each Thank You Ticket below is valid for <i><u>one</u></i> entry.
  //   </div>
  //   <div key="show-tickets-print" className="list-group-item">
  //     <button
  //       onClick={this.print}
  //       type="button"
  //       className="btn btn-block btn-success"
  //     >
  //       Click Here to Print/Save as PDF
  //     </button>
  //   </div>
  //   <div key="ticket-wrapper" className="list-group-item">
  //     <iframe
  //       title="generated-tickets"
  //       id="print-tickets"
  //       src={`/api/generate_thank_you_tickets/${this.idHash}?for_print=1&${this.ticketParams}`}
  //       frameBorder="0"
  //     />
  //   </div>
  // </>

  copyLink = () => {
    return CopyClip.unprompted(this.ticketLink)
  }

  resetTickets = () => this.setState({ tickets: null })

  renderTicket = () => <>
    <div key="reset-wrapper" className="list-group-item">
      <button
        className="btn btn-block btn-warning"
        onClick={this.resetTickets}
      >
        RESET
      </button>
    </div>
    <div key="link-wrapper" className="list-group-item pt-5">
      <div className="row">
        <div className="col-12">
          <div className="d-flex flex-row align-items-center justify-content-center">
            <img src={this.ticket.qr_code} alt="QR CODE"/>
          </div>
        </div>
        <div className="col-12">
          <p className="text-center">
            Redeem Ticket: <Link
              to={this.ticketLink}
              onClick={this.emailLink}
              target="_ticket"
            >{ this.ticketLink }</Link>
          </p>
        </div>
        <div className="col-md-4">
          <button
            className="btn btn-block btn-success"
            onClick={this.copyLink}
          >
            Copy To Clipboard
          </button>
        </div>
        <div className="col-md-4">
          <Link
            to={`mailto:?subject=Thank%20You%20For%20Your%20Support&body=${encodeURIComponent(ticketMessage)}%0D%0A${this.ticketLink}`}
            className="btn btn-block btn-success"
            onClick={this.emailLink}
            target="_mailto"
          >
            Email
          </Link>
        </div>
        <div className="col-md-4">
          <Link
            to={`sms:?&body=${ticketMessage} ${this.ticketLink}`}
            className="btn btn-block btn-success"
          >
            Send Text
          </Link>
        </div>
      </div>
    </div>
  </>

  showTickets = () =>
    this.state.tickets.length === 1 && this.renderTicket()

  renderAllowed = () =>
    this.state.loading
      ? (
        <JellyBox className="page-loader" />
      )
      : (
        <>
          <div key="help-text" className="list-group-item">
            Use the buttons below to generate Thank You Tickets.
            Each generated Thank You Ticket is valid for <i><u>one</u></i> entry.
          </div>
          <div key="buttons" className="list-group-item">
            <div className="row">
              <div className="col-md-6">
                <button
                  type="button"
                  className="btn btn-block btn-info"
                  onClick={this.generateTicket}
                >
                  Generate Ticket
                </button>
              </div>
              <div className="col-md-6">
                <button
                  type="button"
                  className="btn btn-block btn-primary"
                  onClick={this.generatePage}
                >
                  Generate Page
                </button>
              </div>
            </div>
          </div>
        </>
      )

  generatePage = () => this.generateTickets(12)
  generateTicket = () => this.generateTickets()

  generateTickets = (count) => {
    count = parseInt(count) || 1
    this.setState({ loading: true, tickets: null }, async () => {
      const fetchUrl = `/api/generate_thank_you_tickets?id=${this.idHash}`

      try {
        await fetch(fetchUrl, { method: "POST" })
        const result =  await fetch(fetchUrl, {
                method: 'POST',
                headers: {
                  "Content-Type": "application/json; charset=utf-8"
                },
                body: JSON.stringify({ count })
              }),
              json = await result.json()

        console.log(json)

        return await this.setStateAsync({ ...json, loading: false })
      } catch(err) {
        console.log(err)
      }
    })
  }

  // print = (ev) => {
  //   ev.stopPropagation()
  //   ev.preventDefault()
  //   if(this.printLocal) return window.print()
  //   else {
  //     const w = window.open()
  //     w.name = '_print_page'
  //     w.opener = null
  //     w.referrer = null
  //     w.location = `/api/generate_thank_you_tickets/${this.idHash}?for_print=1&${this.ticketParams}`
  //     this.setState({ tickets: null })
  //   }
  // }

  render() {
    return (
      <CardSection
        className="ThankYouTicketGeneratorPage my-4"
        label={<div>
          Generate Thank You Tickets
        </div>}
        contentProps={{className: 'list-group'}}
      >
        {
          !!this.state.tickets
            ? this.showTickets()
            : (
              this.state.allowed
                ? this.renderAllowed()
                : (
                  <div className="list-group-item">
                    Please contact a Down Under Sports representative for your generator link.
                    <ul>
                      <li>Email: <a href="mailto:mail@downundersports.com">mail@downundersports.com</a></li>
                      <li>Phone: <a href="tel:435-753-4732">435-753-4732</a></li>
                      <li>Text: <a href="sms:435-753-4732">435-753-4732</a></li>
                    </ul>
                  </div>
                )
            )
        }
      </CardSection>
    );
  }
}
