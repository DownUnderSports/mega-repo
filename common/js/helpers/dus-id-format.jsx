export default function dusIdFormat(val) {
  if(!val) return ''
  val = String(val).replace(/[^A-Za-z]/g, '')
  if(val.length && (val.length > 3)) val = val.slice(0, 3) + '-' + val.slice(3, 6)
  return val.toUpperCase()
}
