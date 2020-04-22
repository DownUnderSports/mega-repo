import React, { PureComponent } from 'react'
import { CardSection, Link } from 'react-component-templates/components'
import OpenTryoutForm from 'common/js/forms/open-tryout-form'
import pixelTracker from 'common/js/helpers/pixel-tracker'

export default class AthleteFormPage extends PureComponent {
  componentDidMount() {
    try {
      pixelTracker('track', 'PageView')
    } catch (e) {
      console.error(e)
    }
  }

  render() {
    return (
      <CardSection
        className="my-5"
        label={`Down Under Sports Athlete Form`}
      >
        <p>
          We are happy to review any athletes wanting to compete with Down Under Sports!
        </p>
        <p>
          For more information, fill out the "Athlete Form" below and we will review your application as soon as possible. If you have any issues/questions/concerns please <Link to="tel:+14357534732">call or text our office @ 435-753-4732</Link> or <Link to="mailto:mail@downundersports.com">send an email to mail@downundersports.com</Link>.
        </p>
        <p className="text-center">
          <i>NOTE: This program is for <u>student athletes</u> ages 15-19</i>
        </p>
        <hr/>
        <hr className="mb-5"/>
        <OpenTryoutForm header='Athlete Form' afterSubmit='Your Information Has Been Submitted!' />
      </CardSection>
    )
  }
}
