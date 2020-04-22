try {
  //eslint-disable-next-line
  window.global = window
} catch(_) {
  //eslint-disable-next-line
  self.global = self
  //eslint-disable-next-line
  self.window = self
}
