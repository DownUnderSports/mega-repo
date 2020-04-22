import React from 'react'
import renderer from 'react-test-renderer';
import ReactTestUtils from 'react-dom/test-utils'
import { CalendarHeader } from '../'

describe('common/js/components - Calendar::Header', () => {
  const div = document.createElement('div');

  const createHeader = ({...props}) => {
    return renderer.create(
      <CalendarHeader {...props} />
    )
  }

  it('renders a semantic header tag', () => {
    const rendered = createHeader()
    expect(rendered).toBeTruthy()
    expect(rendered.toJSON().type).toBe("header")
  })

  it('contains a heading label', () => {
    const heading = createHeader({month: 'test'}).root.findByType('h4')
    expect(heading).toBeTruthy()
    expect(heading.children[0]).toEqual('test')
    expect(heading.type).toBe('h4')
  })

  it('contains a "previous" icon', () => {
    const rendered = createHeader()
    const icon = createHeader({month: 'test'}).root.findByProps({
      'data-function': 'previous-month'
    })
    expect(icon).toBeTruthy()
    expect(icon.children[0]).toEqual('chevron_left')
    expect(icon.type).toBe('i')
  })

  it('contains a "next" icon', () => {
    const rendered = createHeader()
    const icon = createHeader({month: 'test'}).root.findByProps({
      'data-function': 'next-month'
    })
    expect(icon).toBeTruthy()
    expect(icon.children[0]).toEqual('chevron_right')
    expect(icon.type).toBe('i')
  })

  it('takes a click handler for onPreviousMonthClick and onNextMonthClick', () => {
    const mockCallBack = jest.fn(),
          root = createHeader({
            onPreviousMonthClick: () => mockCallBack('prev'),
            onNextMonthClick: () => mockCallBack('next')
          }).root,
          prev = root.findByProps({
            'data-function': 'previous-month'
          }),
          next = root.findByProps({
            'data-function': 'next-month'
          });

    expect(mockCallBack).not.toHaveBeenCalledWith('prev')
    prev.props.onClick()
    expect(mockCallBack).toHaveBeenCalledWith('prev')
    expect(mockCallBack.mock.calls.length).toEqual(1)

    expect(mockCallBack).not.toHaveBeenCalledWith('next')
    next.props.onClick()
    expect(mockCallBack).toHaveBeenCalledWith('next')
    expect(mockCallBack.mock.calls.length).toEqual(2)
  })

  it('is snapshotable', () => {
    const tree = createHeader({
      month: 'test'
    })
    .toJSON();
    expect(tree).toMatchSnapshot()
  })
})
