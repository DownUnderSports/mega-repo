import { Objected } from 'react-component-templates/helpers';

export default function onFormChange( context, k, v, valid, cb = (() => {}), validator = () => true ) {
  return context.setState(state => {
    const form = { ...(state.form || {}) },
          changed = !!state.changed || (Objected.getValue(form, k) !== v)

    Objected.setValue(form, k, (v === undefined ? null : v))
    Objected.setValue(form, `${k}_valid`, valid)
    Objected.setValue(form, `${k}_validated`, true)

    return { form, changed }
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
