export const faqData = [
  {
    question: 'What is Down Under Sports?',
    key: 'DgJDJX0FUao',
    text: `
      For 32 years, Down Under Sports has hosted sports tournaments in Australia. We have recruited tens of thousands of athletes to join us for this once-in-a-lifetime experience to compete internationally, explore the Australian coast, and make unforgettable memories and friends. Check out our website, Facebook page, and google to find reviews. We also have an A+ rating with the Better Business Bureau.
    `
  },
  {
    question: 'Why was I invited?',
    key: 'UirMsupSUQE',
    text: `
      We recruit athletes just like a college does. We get our names from local publications, recruiting websites such as max preps and mile split, and from coach recommendations.
    `
  },
  // {
  //   question: 'When is it?',
  //   key: 'eND7GwRaFEA',
  //   text: `
  //     The Down Under Sports Tournaments take place in June and July each year.
  //   `
  // },
  {
    question: 'Will I be chaperoned?',
    key: 'SfZo6YFYtZ8',
    text: `
      The Down Under Sports programs are fully guided tours. Down Under Sports hand selects local Australians to pick you up from the airport, manage head counts, answer questions and act as "Tour Guides".

      Tour Guides stay in the same hotels as participants and travel on the buses to all events.
    `
  },
  {
    question: 'How will this benefit me?',
    key: '4dY9GxQC9CU',
    text: `
      Our program gives athletes an awesome experience to travel and compete internationally. It's a great opportunity to network with coaches and athletes from all over the US, Australia and New Zealand.

      Also, an international competition never looks bad on a college application!
    `
  },
  {
    question: 'How much does it cost?',
    key: 'kP9QLqh8pGY',
    text: `
      The total cost of the trip is $4699 per person. It includes international airfare, tour guides, hotel accommodations, two meals per day, tournament fees, sight-seeing, a koala photo, and more. We provide each athlete with fundraising tools to help cover the cost. There are ways to earn discounts on the package price.
    `
  },
  {
    question: 'How can I pay for this trip?',
    key: 'Qt8DgXEPYoQ',
    text: `
       We have developed great fundraising tools to help athletes raise money. These fundraising tools include a custom donation webpage where all of the funds donated go directly towards your trip. We also provide you with a sponsorship letter for you to distribute to family, friends, and businesses. We provide you with “thank-you” tickets to give out when someone donates or helps you fundraise for your trip. The tickets get put into a drawing and the winner gets a trip for two to Australia.
    `
  },
  {
    question: 'Can my family and friends come with me?',
    key: 'rD3MUIC0QMc',
    text: `
      Your family and friends can absolutely join you on the trip. Their cost is the same price as yours. We also offer special rates for larger groups.
    `
  },
  {
    question: 'When do I need to sign up?',
    key: 'ce7XzVXoQJI',
    text: `
      We recommend paying your deposit as soon as you have made a decision. It will secure your spot on the team and ensure you are eligible for some great discounts.
    `
  },
].map(({question, key, text}) => ({ question, key, text: text.trim().replace(/^[^\S\n\r\f]*/mg, '') }))


export default faqData
