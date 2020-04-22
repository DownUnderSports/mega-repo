# encoding: utf-8
# frozen_string_literal: true

require_dependency 'sport'

class Sport
  # == Constants ============================================================
  DRIVE_POSTERS = {
    drive: 'https://drive.google.com/open?id=',
    direct: 'https://drive.google.com/uc?id=',
    bb: {
      id: '1JQ1nP0Ygt71Yz4eYSw0FSA1SqDFJ-PyN',
      drive: 'https://drive.google.com/file/d/1JQ1nP0Ygt71Yz4eYSw0FSA1SqDFJ-PyN/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=1JQ1nP0Ygt71Yz4eYSw0FSA1SqDFJ-PyN'
    },
    ch: {
      id: '1-hDFk4yj8hgGVmEP3_y0uwrpQom0OMnc',
      drive: 'https://drive.google.com/file/d/1-hDFk4yj8hgGVmEP3_y0uwrpQom0OMnc/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=1-hDFk4yj8hgGVmEP3_y0uwrpQom0OMnc'
    },
    fb: {
      id: '10VYxpZVWxluVBqzXHmG1tHRFT5UdY5cd',
      drive: 'https://drive.google.com/file/d/10VYxpZVWxluVBqzXHmG1tHRFT5UdY5cd/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=10VYxpZVWxluVBqzXHmG1tHRFT5UdY5cd'
    },
    gf: {
      id: '1tBu5_ZXYJ9etbISAXQ93JJJP_N_atu9C',
      drive: 'https://drive.google.com/file/d/1tBu5_ZXYJ9etbISAXQ93JJJP_N_atu9C/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=1tBu5_ZXYJ9etbISAXQ93JJJP_N_atu9C'
    },
    tf: {
      id: '1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m',
      drive: 'https://drive.google.com/file/d/1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m'
    },
    tf_1: {
      id: '1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m',
      drive: 'https://drive.google.com/file/d/1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m'
    },
    tf_2: {
      id: '1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m',
      drive: 'https://drive.google.com/file/d/1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=1lNhqPLFElm396dPnfFKCC4OZ2O5YIQ9m'
    },
    vb: {
      id: '1UceNb-ZaX1VSClZ-280ljnyJzVyz9Lxb',
      drive: 'https://drive.google.com/file/d/1UceNb-ZaX1VSClZ-280ljnyJzVyz9Lxb/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=1UceNb-ZaX1VSClZ-280ljnyJzVyz9Lxb'
    },
    xc: {
      id: '1zUg4N8N-qrmK3lXba9qID-jDJIamcIdf',
      drive: 'https://drive.google.com/file/d/1zUg4N8N-qrmK3lXba9qID-jDJIamcIdf/view?usp=sharing',
      direct: 'https://drive.google.com/uc?id=1zUg4N8N-qrmK3lXba9qID-jDJIamcIdf'
    },
  }

end
