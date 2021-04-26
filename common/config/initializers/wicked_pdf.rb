wicked_cfg = {
  use_xserver: false,
  page_size: "Letter",
  layout: 'layouts/application',
  dpi: 300,
  margin: {
    top: '.25in',
    bottom: '.25in',
    left: '.25in',
    right: '.25in'
  }
}

WickedPdf.config[:exe_path] = '/usr/bin/wkhtmltopdf'

WickedPdf.config ||= {}
WickedPdf.config.merge!(wicked_cfg)
