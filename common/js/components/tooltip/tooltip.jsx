import React, { PureComponent, Fragment } from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';

export default class Tooltip extends PureComponent {
  static propTypes = {
    children: PropTypes.any.isRequired,
    content: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.array,
    ]),
    styles: PropTypes.object,
    wrapped: PropTypes.bool
  }

  state = { visible: false }

  styles = {
    wrappedWrapper: {
      display: 'inline-block',
      position: 'relative',
      width: '100%'
    },
    wrapper: {
      display: 'block',
      position: 'relative',
      whiteSpace: 'normal !important',
    },
    tooltip: {
      position: 'absolute',
      zIndex: '99',
      bottom: '100%',
      width: '420px',
      left: '50%',
      marginBottom: '10px',
      WebkitTransform: 'translateX(-50%)',
      msTransform: 'translateX(-50%)',
      OTransform: 'translateX(-50%)',
      transform: 'translateX(-50%)',
      display: 'flex',
      justifyContent: 'center',
    },
    fixedTooltip: {
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      width: '100vw',
      background: '#027',
      height: '4rem',
      zIndex: 2000,
      display: 'flex',
      justifyContent: 'center',
      padding: '.5rem'
    },
    tooltipInner: {
      background: '#027',
      display: 'inline-block',
      position: 'relative',
      padding: '.5rem',
    },
    fixedContent: {
      fontWeight: 'normal',
      whiteSpace: 'normal',
      color: '#fff',
      overflowWrap: 'normal',
      wordBreak: 'none',
    },
    content: {
      fontWeight: 'normal',
      whiteSpace: 'normal',
      color: '#fff',
      minWidth: '50px',
      maxWidth: '420px',
      overflowWrap: 'normal',
      wordBreak: 'none',
    },
    fixedArrow: {
      display: 'none'
    },
    arrow: {
      position: 'absolute',
      width: '0',
      height: '0',
      bottom: '-10px',
      left: '50%',
      borderLeft: 'solid transparent 10px',
      borderRight: 'solid transparent 10px',
      borderTop: 'solid #027 10px',
    },
  }

  constructor(props) {
    super(props);
    this.mergeStyles(props.styles || {}, props.wrapped);
  }

  mergeStyles = (userStyles, wrapped) => {
    if(wrapped) {
      Object.assign(this.styles.tooltip, this.styles.wrappedTooltip)
      Object.assign(this.styles.wrapper, this.styles.wrappedWrapper)
    }
    Object.keys(this.styles).forEach((name) => {
      Object.assign(this.styles[name], userStyles[name]);
    });
  }

  show = () => this.setVisibility(true);

  hide = () => this.setVisibility(false);

  setVisibility = (visible) => {
    this.setState({visible});
  }

  handleTouch = () => {
    this.show();
    this.assignOutsideTouchHandler();
  }

  assignOutsideTouchHandler = () => {
    const handler = (e) => {
      let currentNode = e.target;
      const componentNode = ReactDOM.findDOMNode(this.refs.instance);
      while (currentNode.parentNode) {
        if (currentNode === componentNode) return;
        currentNode = currentNode.parentNode;
      }
      if (currentNode !== document) return;
      this.hide();
      document.removeEventListener('touchstart', handler);
    }
    document.addEventListener('touchstart', handler);
  }

  render() {
    const { props, state, styles, show, hide, handleTouch } = this

    return props.wrapped ? (
      <div
        onMouseEnter={show}
        onMouseLeave={hide}
        onTouchStart={handleTouch}
        ref="wrapper"
        style={styles.wrapper}
      >
        {props.children}
        {
          state.visible &&
          <div ref="tooltip" style={styles.tooltip}>
            <div ref="tooltipInner" style={styles.tooltipInner}>
              <div ref="content" style={styles.content}>
                {props.content}
              </div>
              <div ref="arrow" style={styles.arrow} />
            </div>
          </div>
        }
      </div>
    ) : (
      <Fragment>
        <span
          key="label"
          onMouseEnter={show}
          onMouseLeave={hide}
          onTouchStart={handleTouch}
          ref="wrapper"
          style={styles.wrapper}
        >
          {props.children}
        </span>
        {
          state.visible &&
          <span ref="tooltip" style={props.fixed ? styles.fixedTooltip : styles.tooltip}>
            <span ref="tooltipInner" style={styles.tooltipInner}>
              <span ref="content" style={props.fixed ? styles.fixedContent : styles.content}>
                {props.content}
              </span>
              <span ref="arrow" style={props.fixed ? styles.fixedArrow : styles.arrow} />
            </span>
          </span>
        }
      </Fragment>
    )
  }
}
