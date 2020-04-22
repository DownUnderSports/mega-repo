import React from 'react'
import dateFns from 'date-fns'
import renderer from 'react-test-renderer';
import ReactTestUtils from 'react-dom/test-utils'
import { CalendarLabels } from '../'

describe('common/js/components - Calendar::Labels', () => {
  const div = document.createElement('div');

  const createLabels = ({...props}) => {
    return renderer.create(
      <CalendarLabels {...props} />
    )
  }

  it('renders a calendar-labels div', () => {
    const rendered = createLabels()
    expect(rendered).toBeTruthy()
    expect(rendered.toJSON().type).toBe("div")
    expect(rendered.toJSON().props.className.split(' ')[0]).toEqual("calendar-labels")
  })

  it('is a calendar row', () => {
    const rendered = createLabels(),
          classes = rendered.toJSON().props.className.split(' ')
    let rowed = false
    for(let i = 0; i < classes.length; i++) {
      if(classes[i] === 'calendar-row') rowed = true
    }
    expect(rowed).toBeTruthy()
  })

  it('has exactly 7 labels', () => {
    const children = createLabels().root.findAllByProps({
      'data-purpose': 'calendar-label'
    });
    expect(children.length).toEqual(7)
    for(let i = 0; i < 7; i++) {
      expect(children[i].props.className).toEqual('calendar-col col-center')
    }
  })

  it('takes a startDate', () => {
    const d = new Date(),
          child = createLabels({startDate: d}).root.findAllByProps({
            'data-purpose': 'calendar-label'
          })[0].findByProps({
            className: 'col-overflow'
          });

    expect(child.children[0]).toEqual(dateFns.format(d))
  })

  it('takes a labelFormat', () => {
    const startDate = new Date(),
          labelFormat = 'd',
          child = createLabels({startDate, labelFormat}).root.findAllByProps({
            'data-purpose': 'calendar-label'
          })[0].findByProps({
            className: 'col-overflow'
          });

    expect(child.children[0]).toEqual(dateFns.format(startDate, labelFormat))
  })

  it('is snapshotable', () => {
    const tree = createLabels()
    .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
