import React, { Component } from 'react'
import { debounce } from 'react-component-templates/helpers'
import { TextField /*, SelectField*/ } from 'react-component-templates/form-components';

const cardTypes = [
        [
          [ '34', '37' ],
          'American Express',
          () => [ 4, 6, 5 ]
        ],
        [
          [ '62', '88' ],
          'China UnionPay',
          (v) => v.length > 16 ? [ 6, 13 ] : 4
        ],
        [
          [ '5019' ],
          'Dankort',
          () => 4
        ],
        [
          [ '300', '305' ],
          'Diners Club Carte Blanche',
          () => [ 4, 6, 4 ]
        ],
        [
          [ '2014', '2149' ],
          'Diners Club enRoute',
          () => [ 4, 7, 4 ]
        ],
        [
          [ [ '300', '305' ], '309', '36', [ '38', '39' ] ],
          'Diners Club International',
          () => [ 4, 6, 4 ]
        ],
        [
          [ '54', '55' ],
          'Diners Club US & Canada',
          () => 4
        ],
        [
          [ '6011', [ '622126', '622925' ], [ '644', '649' ], '65' ],
          'Discover Card',
          () => 4
        ],
        [
          [ '636' ],
          'InterPayment',
          () => 4
        ],
        [
          [ [ '3528', '3589' ] ],
          'JCB',
          () => 4
        ],
        [
          [ '6304', '6706', '6771', '6709' ],
          'Laser',
          () => 4
        ],
        [
          [ ['500', '509'], [ '560', '589' ], ['60', '69'] ],
          'Maestro',
          (v) => {
            switch (v.length) {
              case 13:
                return [ 4, 4, 5 ];
              case 15:
                return [ 4, 6, 5 ];
              default:
                return 4;
            }
          }
        ],
        [
          [ [ '51', '55' ], [ '22210', '27209' ] ],
          'MasterCard',
          () => 4
        ],
        [
          [ '4026', '417500', '4405', '4508', '4844', '4913', '4917' ],
          'Visa Electron',
          () => 4
        ],
        [
          [ '1' ],
          'UATP',
          () => 4
        ],
        [
          [ '4' ],
          'Visa',
          () => 4
        ],
      ]

export default class CreditCardField extends Component {
  state = {
    card: '',
    cvv: '',
    month: '',
    year: '',
    cardFormat: () => 4,
    cardType: '',
    cardValidated: false,
    monthValidated: false,
    yearValidated: false,
    cvvValidated: false,
    cvvPattern: '[0-9]{3,4}',
  }

  constructor(props) {
    super(props)
    this.getCardType = debounce(this.getCardType, 100)
  }

  componentDidUpdate(_, prevState) {
    if(this.state.card){
      if(prevState.card.replace(/[^0-9]/g, '') !== this.state.card.replace(/[^0-9]/g, '')) {
        if(prevState.card.slice(0, 6) !== this.state.card.slice(0, 6)) this.getCardType()
        this.cardEl.setCustomValidity(
          this.checkLuhn() ? '' : 'The Card Number Entered is Invalid'
        )
      }
    }
  }

  getCardType = () => {
    let card = (this.state.card || '').replace(/[^0-9]/g, '')
    for(let i = 0; i < cardTypes.length; i++) {
      const types = cardTypes[i][0],
            cardType = cardTypes[i][1],
            cardFormat = cardTypes[i][2]

      let isType;
      for(let t = 0; t < types.length; t++) {
        const type = types[t]
        isType = Array.isArray(type) ? this.checkTypeRange(card, ...type) : this.checkType(card, type)
        if(isType)
          break;
      }

      if(isType) return this.setState({
        cardType,
        cardFormat,
        cvvPattern: cardType === 'American Express' ? '[0-9]{4}' : '[0-9]{3,4}'
      }, () => {
        const card = this.cardFormat(this.state.card)
        if(this.state.card !== card) this.setState({card})
      })
    }
  }

  checkTypeRange(card, low, high) {
    const digits = low.length;
    low = parseInt(low, 10)
    high = parseInt(high, 10)
    card = parseInt(card.slice(0, digits), 10)
    return !!((card >= low) && (card <= high))
  }

  checkType(card, type) {
    return !!(new RegExp(`^${type}`).test(card))
  }

  onChange = (e) => {
    const target = e.target,
          key = target.dataset.fieldName
    if(key === 'card') {
      target.value = this.cardFormat(target.value)
    }
    this.setState({
      [key]: target.value,
      [`${key}Validated`]: true
    }, () => {
      this.afterChange(key, target.value)
    })
  }

  afterChange(key, value) {
    key = key[0].toUpperCase() + key.slice(1)
    if(this.props[`on${key}Change`]) this.props[`on${key}Change`](`${value}`.replace(/[^0-9]/g, ''))
  }

  cardFormat = (val) => {
    val = `${val}`.replace(/[^0-9]/g, '')
    if(val.length) {
      let currentFormat = this.state.cardFormat(val)

      if(!Array.isArray(currentFormat)) currentFormat = [...Array(6)].map(_ => currentFormat);
      for(let i = currentFormat.length; i > 0; i--) {
        let len = currentFormat.slice(0, i).reduce((total, v) => total + v)
        if(val.length > len) val = `${val.slice(0, len)} ${val.slice(len)}`
      }
    }
    return val
  }

  // onSelectChange = (k, v) => this.setState({[k]: v, [`${k}Validated`]: true})

  // onMonthChange = (_, value) => this.onSelectChange('month', value.value)

  // onYearChange = (_, value) => this.onSelectChange('year', value.value)

  // monthFilterOptions = {
  //   indexes: [ 'value', 'single', 'abbr', 'full' ]
  // }
  //
  // yearFilterOptions = {
  //   indexes: [ 'value' ]
  // }

  checkLuhn = () => {
    if(this.state.card.length > 12) {
      if(!this.state.cardValidated) this.setState({cardValidated: true})

      let sum = 0, card = this.state.card.replace(/[^0-9]/g, '').reverse()

      for(let i = 0; i < card.length; i++) {
        let val = parseInt(card[i], 10)
        if(i % 2) sum = sum + `${val * 2}`.split('').map((v) => parseInt(v, 10)).reduce((t, v) => t + v);
        else sum = sum + val
      }

      return !(sum % 10)
    } else {
      return false
    }
  }

  cardRef = (el) => this.cardEl = el && el.refs.input

  render() {
    return (
      <div className={`credit-card-section p-3 bg-light rounded border border-secondary mb-3 ${this.props.className}`}>
        <div className="row">
          <div
            className={`col form-group ${this.state.cardValidated ? 'was-validated' : ''}`}
            {...this.props.cardWrapperProps}
          >
            <TextField
              ref={this.cardRef}
              name='card'
              label='Card Number'
              className='form-control'
              data-field-name='card'
              value={this.state.card}
              pattern='([0-9] ?){12,}'
              onChange={this.onChange}
              caretIgnore=' '
              inputMode='numeric'
              {...this.props.cardProps || {}}
            />
          </div>
        </div>
        <div className="row">
          <div
            className={`col-sm form-group ${this.state.cvvValidated ? 'was-validated' : ''}`}
            {...this.props.cvvWrapperProps}
          >
            <TextField
              name='cvvCode'
              label='CVV Code'
              className='form-control'
              data-field-name='cvv'
              value={this.state.cvv}
              pattern={this.state.cvvPattern || '[0-9]{3,4}'}
              onChange={this.onChange}
              inputMode='numeric'
              min='3'
              max='4'
              {...this.props.cvvProps || {}}
            />
          </div>
          <div className="col-sm">
            <div className="row">
              <div
                className={`col form-group ${this.state.monthValidated ? 'was-validated' : ''}`}
                {...this.props.monthWrapperProps}
              >
                <TextField
                  name='month'
                  label='Exp. Month'
                  className='form-control'
                  data-field-name='month'
                  value={this.state.month}
                  pattern={`[01]${this.state.month[0] === '1' ? '[0-2]' : '[1-9]'}`}
                  min='2'
                  max='2'
                  onChange={this.onChange}
                  inputMode='numeric'
                  {...this.props.monthProps || {}}
                />
              </div>
              <div
                className={`col form-group ${this.state.yearValidated ? 'was-validated' : ''}`}
                {...this.props.monthWrapperProps}
              >
                <TextField
                  name='year'
                  label='Exp. Year'
                  className='form-control'
                  data-field-name='year'
                  value={this.state.year}
                  pattern='([0-9]{2}|[0-9]{4})'
                  min='2'
                  max='2'
                  onChange={this.onChange}
                  inputMode='numeric'
                  {...this.props.yearProps || {}}
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    )
  }
}
// currentYear = (new Date()).getFullYear(),
// monthOptions = [
//   {
//     value:  '01',
//     label:  '01',
//     single: '1',
//     abbr:   'Jan',
//     full:   'January'
//   },
//   {
//     value:  '02',
//     label:  '02',
//     single: '2',
//     abbr:   'Feb',
//     full:   'February'
//   },
//   {
//     value:  '03',
//     label:  '03',
//     single: '3',
//     abbr:   'Mar',
//     full:   'March'
//   },
//   {
//     value:  '04',
//     label:  '04',
//     single: '4',
//     abbr:   'Apr',
//     full:   'April'
//   },
//   {
//     value:  '05',
//     label:  '05',
//     single: '5',
//     abbr:   'May',
//     full:   'May'
//   },
//   {
//     value:  '06',
//     label:  '06',
//     single: '6',
//     abbr:   'Jun',
//     full:   'June'
//   },
//   {
//     value:  '07',
//     label:  '07',
//     single: '7',
//     abbr:   'Jul',
//     full:   'July'
//   },
//   {
//     value:  '08',
//     label:  '08',
//     single: '8',
//     abbr:   'Aug',
//     full:   'August'
//   },
//   {
//     value:  '09',
//     label:  '09',
//     single: '9',
//     abbr:   'Sep',
//     full:   'September'
//   },
//   {
//     value:  '10',
//     label:  '10',
//     single: '10',
//     abbr:   'Oct',
//     full:   'October'
//   },
//   {
//     value:  '11',
//     label:  '11',
//     single: '11',
//     abbr:   'Nov',
//     full:   'November'
//   },
//   {
//     value:  '12',
//     label:  '12',
//     single: '12',
//     abbr:   'Dec',
//     full:   'December'
//   },
// ],
// yearOptions = [...Array(50)].map((_, i) => {
//   console.log(currentYear)
//   const year = (currentYear + i),
//         yearStr = `${year}`.slice(2)
//   return {
//     value: yearStr,
//     label: yearStr,
//   }
// }),

// <SelectField
//   name='month'
//   label='Exp. Month'
//   value={this.state.month}
//   options={monthOptions}
//   onChange={this.onMonthChange}
//   filterOptions={this.monthFilterOptions}
//   viewProps={{
//     className: 'form-control',
//     autoComplete: `cc-exp-month`,
//     required: true,
//   }}
//   skipExtras
//   {...this.props.monthProps || {}}
// />
// <SelectField
//   name='year'
//   label='Exp. Year'
//   value={this.state.year}
//   options={yearOptions}
//   onChange={this.onYearChange}
//   filterOptions={this.yearFilterOptions}
//   viewProps={{
//     className: 'form-control',
//     autoComplete: `cc-exp-year`,
//     required: true,
//   }}
//   skipExtras
//   {...this.props.yearProps || {}}
// />
