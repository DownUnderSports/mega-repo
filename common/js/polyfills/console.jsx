if(!console.error) {
  if(!console.exception) console.exception = console.log
  console.error = console.exception
}

if(!console.info) console.info = console.log
