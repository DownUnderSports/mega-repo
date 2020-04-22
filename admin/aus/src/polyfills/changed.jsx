if (!Object.changed) {
  Object.changed = function(o, n, shallow = true) {
    if(typeof o !== typeof n) return true
    if(Object.isPureObject(o)) {
      const keys = Array.unique([...Object.keys(o), ...Object.keys(n)])

      for( let i = 0; i < keys.length; i++) {
        if(o[keys[i]] !== n[keys[i]]) {
          if(shallow) return true
          else if(Object.changed(o[keys[i]], n[keys[i]], true)) return true
        }
      }

      return false
    } else if(Array.isArray(o)) {
      if(o.length !== n.length) return true

      for( let i = 0; i < o.length; i++) {
        if(o[i] !== n[i]) {
          if(shallow) return true
          else if(Object.changed(o[i], n[i], true)) return true
        }
      }
    } else {
      return o === n
    }
  }
}
