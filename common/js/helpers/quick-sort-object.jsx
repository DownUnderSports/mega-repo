const smaller = (obj, by, pivot) => {
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
      const comp = obj[propVal], pivComp = pivot[propVal]
      if(comp === pivComp) continue;
      return reversed ? comp > pivComp : comp < pivComp
    }
  } else {
    if(typeof obj === "string" || typeof obj === "number") return obj < pivot

    return obj[by] < pivot[by]
  }
}

const greater = (obj, by, pivot) => {
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
      const comp = obj[propVal], pivComp = pivot[propVal]
      if(comp === pivComp) continue;
      return reversed ? comp < pivComp : comp > pivComp
    }
  } else {
    if(typeof obj === "string" || typeof obj === "number") return obj > pivot

    return obj[by] > pivot[by]
  }
}

const quickPart = (arr, by, l, r) => {
  const pivot = arr[(r + l)/2 | 0]
  while(l <= r){
    while(smaller(arr[l], by, pivot)) l++
    while(greater(arr[r], by, pivot)) r--
    if(l <= r){
      [arr[l], arr[r]]  = [arr[r], arr[l]]
      l++
      r--
    }
  }
  return l
}

const quickSort = (arr, by = 'id', l = 0, r = arr.length -1) => {
  let i
  if(arr.length > 1){
    i = quickPart(arr, by, l, r)
    if(l < i - 1) quickSort(arr, by, l, i - 1)
    if(i < r) quickSort(arr, by, i, r)
  }
  return arr
}

export default quickSort;
