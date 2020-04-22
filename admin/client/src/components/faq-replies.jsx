import React, { Component } from 'react'
import faqData from 'common/js/constants/faq-data'
import CopyClip from 'common/js/helpers/copy-clip'
import flashMessage from 'common/js/helpers/flash-message'

const mappedData = {}
for (let i = 0; i < faqData.length; i++) {
  const datum = faqData[i]
  mappedData[datum.key] = datum;
}

export default class FaqReplies extends Component {
  getData(el){
    if(!el) return {}
    const key = el.dataset.key || ''
    return mappedData[key] || {}
  }

  onClick = (ev) => {
    ev.preventDefault()
    ev.stopPropagation()

    const { question, text, key } = this.getData(ev.currentTarget)

    if(this.props.onClick) return this.props.onClick({question, text, key})
    else if(text) {
      CopyClip.unprompted(text)
      flashMessage(`${question} answer copied to clipboard!`)
    }
  }

  render() {
    const { className = '', buttonClassName = 'btn btn-secondary' } = this.props
    return (
      <div className="row">
        <div className="col">
          <div className={className}>
            {
              faqData.map(({ question, key }) => (
                <button
                  key={key}
                  onClick={this.onClick}
                  data-key={key}
                  className={buttonClassName}
                >
                  { question }
                </button>
              ))
            }
          </div>
        </div>
      </div>
    )
  }
}
