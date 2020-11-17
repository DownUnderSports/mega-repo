export function defaultComparator(a, b) {
  if (a < b) {
    return -1;
  }
  if (a > b) {
    return 1;
  }
  return 0;
};

function compareByKey(key) {
  return (a, b) => defaultComparator(a[key], b[key])
};

function runSort(array, comparator) {
  const sortSection = (start, end) => {

    if (end - start < 1) return;

    const pivotValue = array[end];
    let splitIndex = start;
    for (let i = start; i < end; i++) {
      const sort = comparator(array[i], pivotValue);

      if (sort === -1) {
        if (splitIndex !== i) {
          const temp = array[splitIndex];
          array[splitIndex] = array[i];
          array[i] = temp;
        }

        splitIndex++;
      }
    }

    array[end] = array[splitIndex];
    array[splitIndex] = pivotValue;

    sortSection(start, splitIndex - 1);
    sortSection(splitIndex + 1, end);
  }

  sortSection(0, array.length - 1)

  console.log(array)

  return array
}

export function quickSort(unsorted, compare) {
  switch (typeof (compare || null)) {
    case "string":
      return runSort([ ...unsorted ], compareByKey(compare) || defaultComparator)
    case "function":
      return runSort([ ...unsorted ], compare)
    default:
      return runSort([ ...unsorted ], defaultComparator)
  }
}
