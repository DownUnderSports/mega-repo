import basketballJersey from './basketball-jersey.jpg'
import basketballShorts from './basketball-shorts.jpg'
import golfPolo from './golf-polo.jpg'
import footballJersey from './football-jersey.jpg'
import footballShorts from './football-shorts.jpg'
import trackAndCrossCountryMenJersey from './track-and-cross-country-men-jersey.jpg'
import trackAndCrossCountryMenShorts from './track-and-cross-country-men-shorts.jpg'
import trackAndCrossCountryWomenJersey from './track-and-cross-country-women-jersey.jpg'
import trackAndCrossCountryWomenShorts from './track-and-cross-country-women-shorts.jpg'
import volleyballJersey from './volleyball-jersey.jpg'
import volleyballShorts from './volleyball-shorts.jpg'

export { default as basketballJersey } from './basketball-jersey.jpg'
export { default as basketballShorts } from './basketball-shorts.jpg'
export { default as golfPolo } from './golf-polo.jpg'
export { default as footballJersey } from './football-jersey.png'
export { default as footballShorts } from './football-shorts.png'
export { default as trackAndCrossCountryMenJersey } from './track-and-cross-country-men-jersey.jpg'
export { default as trackAndCrossCountryMenShorts } from './track-and-cross-country-men-shorts.jpg'
export { default as trackAndCrossCountryWomenJersey } from './track-and-cross-country-women-jersey.jpg'
export { default as trackAndCrossCountryWomenShorts } from './track-and-cross-country-women-shorts.jpg'
export { default as volleyballJersey } from './volleyball-jersey.jpg'
export { default as volleyballShorts } from './volleyball-shorts.jpg'

const uniforms = {
  'basketball-jersey': basketballJersey,
  'basketball-shorts': basketballShorts,
  'football-jersey': footballJersey,
  'football-shorts': footballShorts,
  'volleyball-jersey': volleyballJersey,
  'volleyball-shorts': volleyballShorts,
  'track-and-cross-country': {
    'men-jersey': trackAndCrossCountryMenJersey,
    'men-shorts': trackAndCrossCountryMenShorts,
    'women-jersey': trackAndCrossCountryWomenJersey,
    'women-shorts': trackAndCrossCountryWomenShorts,
  },
  basketballJersey,
  basketballShorts,
  golfPolo,
  footballJersey,
  footballShorts,
  trackAndCrossCountryMenJersey,
  trackAndCrossCountryMenShorts,
  trackAndCrossCountryWomenJersey,
  trackAndCrossCountryWomenShorts,
  volleyballJersey,
  volleyballShorts,
}

export default uniforms
