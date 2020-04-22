import Footer from 'common/js/layouts/site/footer'

export default class AdminFooter extends Footer {
  links = [
    {
      to: "https://www.bbb.org/us/ut/north-logan/profile/athletic-organizations/down-under-sports-1166-2001870/#sealclick",
      // children: [
      //   <img key={1} src="https://seal-utah.bbb.org/logo/ruvtbul/bbb-2001870.png" alt="Down Under Sports BBB Business Review" />
      //
      // ],
      className: 'bbb-logo',
      style: {
        backgroundImage: 'url(https://seal-utah.bbb.org/logo/ruvtbul/bbb-2001870.png)',
        backgroundRepeat: 'no-repeat',
        backgroundSize: '200%',
      }
    },
    {
      to: "https://www.travelexinsurance.com/partners/login.aspx?location=44-0083",
      className: 'travelex-link',
      style: {
        backgroundImage: 'url(https://www.travelexinsurance.com/App_Themes/TIS/images/master_sprite1.png)',
        backgroundRepeat: 'no-repeat',
        backgroundPosition: '72.179% 0%',
        backgroundSize: '500%',
      }
    },
  ]
}
