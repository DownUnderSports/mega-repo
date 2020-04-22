export default function dusIdFormat(val) {
  if(!val) return ''
  val = String(val).replace(/[^A-Za-z]/g, '')
  if(val.length && (val.length > 3)) val = val.slice(0, 3) + '-' + val.slice(3, 6)
  return val.toUpperCase()
}

export function isValidUrl(id) {
  return `/aus/valid_user/${id}?path=${encodeURIComponent(window.location.pathname)}`
}

export const userIsValid = async (dusId, context = {}) => {
  context = context || {}

  if(dusId && ((dusId = dusIdFormat(String(dusId || ''))).length === 7)) {
    try {
      context._fetchable = fetch(isValidUrl(dusId))

      await context._fetchable

      return dusId
    } catch(e) {
      if(e.response && (e.response.status === 401)) {
        return false
      } else {
        console.error(e)
        throw e
      }
    }
  }

  return false
}
