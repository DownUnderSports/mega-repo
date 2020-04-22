import { Objected } from 'react-component-templates/helpers';

export default function onFormChange( context, k, v, valid, cb = (() => {}), validator = () => true) {
  return context.setState((prevState) => {
    prevState.changed = prevState.changed || Objected.getValue(prevState.form, k) !== v

    Objected.setValue(prevState.form, k, (v === undefined ? null : v))
    Objected.setValue(prevState.form, `${k}_valid`, valid)
    Objected.setValue(prevState.form, `${k}_validated`, true)

    return prevState
  }, cb)
}

export function deleteValidationKeys(obj) {
  for(let k in obj) {
    if(obj.hasOwnProperty(k)){
      if(/_valid/.test(k)) {
        delete obj[k]
      } else if(typeof obj[k] === 'object') {
        deleteValidationKeys(obj[k])
      }
    }
  }
  return obj
}
