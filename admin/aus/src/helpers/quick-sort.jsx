const getValue = (obj, key) => {
  // console.log(typeof obj !== "object" && obj)
  switch(typeof obj) {
    case "undefined":
    case "string":
    case "number":
    case "boolean":
      return String(obj || '')
    case "object":
      return getValue(obj[key], key)
    default:
      return ''
  }
}

const compare = (obj, obj2, by, direction = "lesser") => {
  if(by instanceof Array){
    for(let i = 0; i < by.length; i++){
      const prop = by[i]
      let propVal, reversed
      if(typeof prop === "object"){
        propVal = prop.value
        reversed = prop.reversed
      } else {
        propVal = prop
        reversed = false
      }

      let obj1Val = getValue(obj, propVal),
          obj2Val = getValue(obj2, propVal)

      if(obj1Val === obj2Val) continue;

      if(reversed) [ obj1Val, obj2Val ] = [ obj2Val, obj1Val ]

      if(direction === "greater") [ obj1Val, obj2Val ] = [ obj2Val, obj1Val ]

      return obj1Val < obj2Val
    }
    return direction !== "lesser"
  } else {
    let obj1Val = getValue(obj, by),
        obj2Val = getValue(obj2, by);

    switch(direction) {
      case "lesser":
        return obj1Val < obj2Val
      case "equal":
        return obj1Val === obj2Val
      case "greater":
        return obj1Val >= obj2Val
      default:
        return false
    }
  }
}

const lesser = (obj, pivot, by) => {
  return compare(obj, pivot, by, 'lesser')
}

const equal = (obj, pivot, by) => {
  return compare(obj, pivot, by, 'equal')
}

const greater = (obj, pivot, by) => {
  return compare(obj, pivot, by, 'greater')
}

const swap = (arr, l, r) => {
  [ arr[l], arr[r] ] = [ arr[r], arr[l] ]
}

const quickPart = (arr, by, l, r) => {
  const m = (r + l) / 2 | 0

  if(r > 100) {
    if(lesser(arr[m], arr[l], by)) swap(arr, m, l)
    if(lesser(arr[r], arr[l], by)) swap(arr, l, r)
    if(lesser(arr[m], arr[r], by)) swap(arr, m, r)
  }

  const pivot = arr[m]


  while(l < r){
    const min = l, max = r
    let isLesser = true,
        isGreater = true
    while(isLesser || isGreater) {
      isLesser = (l < max) && lesser(arr[l], pivot, by) && l++
      isGreater = (r > min) && greater(arr[r], pivot, by) && r--
    }

    if(l === r) l++
    else if(l < r){
      if(!equal(arr[l], arr[r], by)) swap(arr, l, r)
      l++
      r--
    }
  }
  if(!equal(arr[r], pivot, by)) swap(arr, m, r)
  return l
}

const quickSort = (arr, by = 'id', l = 0, r = arr.length - 1) => {
  let i = r
  if(arr.length > 1){
    i = Math.min(r, quickPart(arr, by, l, r))
    if(l < i - 1) quickSort(arr, by, l, i - 1)
    if(i < r) quickSort(arr, by, i, r)
  }
  return arr
}

export default quickSort;
