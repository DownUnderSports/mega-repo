import React, { Component } from 'react';
import { LazyImage, Link } from 'react-component-templates/components'
import pixelTracker from 'common/js/helpers/pixel-tracker'
import DemoVideo from 'common/js/components/demo-video'

// import { HomeGallery } from 'common/js/contexts/home-gallery'

import './home.css'

import georgeAndShelley from 'common/assets/images/george-and-shelley.jpg';
import haka from 'common/assets/images/haka.jpg';
import homepage from 'common/assets/images/homepage.jpg';
import ten from 'common/assets/images/10.svg'

class HomePage extends Component {
  componentDidMount() {
    pixelTracker('track', 'PageView')
  }

  render() {
    return (
      <div className="HomePage">
        <section className="my-4">
          <header className="block-header">
            <h1>
              Who Are We?
            </h1>
          </header>
          <div className="row">
            <div className="col-lg-7 order-2">
              <p>
                Since 1989, Down Under Sports has been hosting sports
                tournaments in Australia. We personally invite high school
                athletes to compete in the annual Down Under Sports Tournaments
                in Queensland, Australia each summer. We seek athletes who
                we believe will benefit the most from our program. Our goal is
                to see our participants grow through this life changing
                experience, both in their sport and as people. These renowned
                tournaments are an opportunity for athletes from different
                countries to compete on an international level.  We pride
                ourselves on providing these opportunities to compete and
                experience the culture, beauty, and grandeur of Australia. We
                dedicate ourselves to ensuring that our athletes and their
                families are prepared for the experience of a lifetime.
              </p>
              <p>
                Over the years we have helped tens of thousands of high school
                athletes showcase their talents on the international stage. {/*
                We have many great reviews from athletes and their parents
                who have traveled with us. You can check out our reviews on&nbsp;
                <Link
                  to="https://www.facebook.com/DownUnderSports/reviews/"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Facebook
                </Link>
                ,&nbsp;
                <Link
                  to="https://g.co/kgs/wQQV9k#lkt=LocalPoiReviews&lrd=0x87547db85c286b91:0xbf6175aa5e7f710f,1,,"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Google
                </Link>
                , and the&nbsp;
                <Link
                  to="https://www.bbb.org/us/ut/north-logan/profile/athletic-organizations/down-under-sports-1166-2001870/#sealclick"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Better Business Bureau
                </Link>
                , where we have an A+ rating!
                */}
              </p>
              {/*
                <p>
                  <i>
                    To learn more about our fantastic staff who work their hardest
                    to make this experience consistently great,&nbsp;
                    <Link to="/our-staff">click here.</Link>
                  </i>
                </p>
              */}
            </div>
            <div className="col order-1 order-lg-12 mb-4">
              <DemoVideo />
              <LazyImage
                className="d-none d-lg-block"
                src={ten}
                alt='10 days to travel, compete, and see Australia'
                title="10 days to travel, compete, and see Australia"
                useLoader
              />
            </div>
          </div>
        </section>
        <section className="my-4">
          <header className="block-header">
            <h1>
              Our Story
            </h1>
          </header>
          <div className="row">
            <div className="col mb-3">
              <div className="framed text-blue text-center">
                <img src={georgeAndShelley} alt="Founders George and Shelley O'Scanlon" />
                <div style={{paddingTop: 0}}>
                  <i>
                    Founders George and Shelley
                  </i>
                </div>
              </div>
            </div>
            <div className="col-md-8">
              <p>
                Down Under Sports was founded in 1989, based on the dream of two
                New Zealanders named George and Shelley O&rsquo;Scanlon. They
                fell in love with athletics, especially American football
                (gridiron). Their dream was to promote football in Australia
                and New Zealand. In 1979, George founded the New Zealand
                American Football Association (NZAFA). This was the first time
                that American Football was played down under! In 1989, they
                began inviting American high school football players to compete
                in New Zealand and Australia. Over the years, this tournament,
                which is known as the &ldquo;Down Under Bowl&rdquo;, started to
                see overwhelming success.
              </p>
              <p>
                We saw this as an exciting opportunity to include other young
                athletes in this fun and rewarding experience. Over the last
                three decades, Down Under Sports has shared the land down under
                with thousands of athletes from all across the United States!
                No matter the sport, the goal has been the same: to use the
                common language of sports to bridge the continents. Through Down
                Under Sports, countless friendships and memories have been made.
              </p>
            </div>
          </div>
        </section>
        <section className="my-4">
          <header className="block-header">
            <h1>
              Our Mission Statement
            </h1>
          </header>
          <div className="row">
            <div className="col-md">
              <p>
                Down Under Sports believes that sport is the international
                language common to all the countries and people around the
                world and that it can help remove cultural and international
                barriers. Therefore, the mission of Down Under Sports is to
                promote the growth, development, and self-esteem of the
                individual athlete through sport; to raise the level and
                awareness and competition to the benefit of both the host
                country and the participating athlete; to forge friendships
                that bridge the gap of both distance and time, through mutual
                competition that promotes health and sportsmanship.
              </p>
            </div>
            <div className="col">
              <div className="framed text-blue">
                <img src={homepage} alt="Bridge the Continents"/>
                <div>
                  <q>
                    <i>
                      ...to use the common language of sports to bridge the
                      continents.
                    </i>
                  </q>
                  <div className="text-right">
                    -- George O&rsquo;Scanlon, Founder
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
        <section className="my-4">
          <header className="block-header">
            <h1>
              Our Vision
            </h1>
          </header>
          <div className="row">
            <div className="col-md-8 order-2">
              <p>
                Our vision is to continue to carry out the dream of our
                founders: to unite continents through sports. We will continue
                to provide athletes the opportunity to experience the culture,
                beauty, and grandeur of the land down under, all within the
                framework of spirited and intense competition. We will continue
                to give athletes and their families, an experience that they
                will cherish forever.
              </p>
              <p>
                We are committed to providing all of our participants and their
                supporters the experience of a lifetime. We work year-round to
                provide a safe, culturally rich, and competitive sports
                tournament to all those who participate in our program.
              </p>
            </div>
            <div className="col order-12 order-md-1">
              <div className="framed text-center text-blue">
                <img src={haka} alt="New Zealand football players perform The Haka" />
                <div>
                  <i>
                    New Zealanders perform <span style={{whiteSpace: 'nowrap'}}>&ldquo;The Haka&rdquo;</span>
                  </i>
                </div>
              </div>
            </div>
          </div>
        </section>
        <Link className='authBtn' to="/infokit">Request More Information</Link>
      </div>
    );
  }
}

export default HomePage;
