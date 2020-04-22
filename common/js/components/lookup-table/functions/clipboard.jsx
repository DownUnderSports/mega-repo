import CopyClip from 'common/js/helpers/copy-clip'

export function copyField(e) {
  e.preventDefault()
  e.stopPropagation()
  CopyClip.prompted(e.currentTarget.innerText)
}

export function copyable(k) {
  return this.props.copyFields &&
    (
      this.props.copyFields.includes(k) ||
      (
        this.aliasFields[k] &&
        this.props.copyFields.includes(this.aliasFields[k])
      )
    )
}
