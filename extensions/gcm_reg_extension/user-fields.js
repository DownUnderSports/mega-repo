(function() {
  if(window._autoGCMFillerIsSetUp) return false

  window._autoGCMFillerIsSetUp = true

  const raceNumber   = document.getElementById('MainContent_Q~1131');

  const setField = (k, v) => new Promise(res => {
    document.getElementById(k).value = v
    setTimeout(res, 100)
  })

  if(/SelectRace.aspx/.test(window.location.pathname)) {
    const findButton = (el) => {
      const divs = el.getElementsByClassName('raceselectorbottomdiv')
      let goodDiv
      for (let i = 0; i < divs.length; i++) {
        const div = divs[i]
        divLabels = div.getElementsByTagName('SPAN')

        for (let hi = 0; hi < divLabels.length; hi++) {
          const h = divLabels[hi].innerText
          if(/Gold Coast Airport Fun Run/.test(h)) {
            hi = divLabels.length + 1
            i = divs.length + 1
            goodDiv = div
          }
        }
      }
      if(goodDiv) {
        const divs = goodDiv.getElementsByClassName('raceselectorbottomdiv')
        if(divs.length) {
          return findButton(goodRow)
        } else {
          return goodDiv
        }
      }
    }

    const wrapperDiv = findButton(document)
    if(wrapperDiv) {
      const inputs = wrapperDiv.getElementsByTagName("INPUT")
      for (let i = 0; i < inputs.length; i++) {
        const input = inputs[i]
        if(input.type === "submit" && /MainContent_RaceRepeater_SelectButton/.test(input.id)) {
          i = inputs.length + 1
          input.click()
        }
      }

    }

  } else if(/RaceEntryDetails.aspx/.test(window.location.pathname)) {
    (async () => {
      await setField('MainContent_GoalFinishTime', 'ZA')
      await setField('MainContent_StartZoneChange', 'ZA')
      await setField('MainContent_RaceBibName', 'FirstName')
      await new Promise((res) => {
        document.getElementById('MainContent_TeamEntry').click()
        setTimeout(res, 100)
      })
      await setField('MainContent_TeamName', 'Down Under Sports')
      await setField('MainContent_TeamHF',   '3843')
      await setField('MainContent_TeamPIN',   'DUS20XC')
      document.getElementById('MainContent_NextButton').click()
    })()
  } else if(/ExtraInfo.aspx/.test(window.location.pathname)) {
    (async () => {
      await setField('MainContent_Q~1131', 'Gold Coast')
      await new Promise((res) => {
        try {
          document.getElementById('MainContent_Q~1471').click()
          setTimeout(res, 100)
        } catch(_) {}
      })
      let shirtValue
      await new Promise(async (res) => {
        try {
          shirtValue = sessionStorage.getItem('dusShirtSize') || ''
          sessionStorage.removeItem('dusShirtSize')

          if(/Y-?/.test(shirtValue)) {
            shirtValue = 'X-Small'
          } else {
            switch (shirtValue.replace(/A-/, '')) {
              case 'S':
                shirtValue = 'Small'
                break;
              case 'M':
                shirtValue = 'Medium'
                break;
              case 'L':
                shirtValue = 'Large'
                break;
              case 'XL':
                shirtValue = 'Large'
                break;
              case 'XL':
                shirtValue = 'Large'
                break;
              case 'XXL':
              case '2XL':
              case '3XL':
              case '4XL':
                shirtValue = 'XX-Large'
                break;
              default:
                shirtValue = false
            }
          }
          if(!shirtValue) throw new Error("not set")
          await setField('MainContent_Q~1144', shirtValue)
        } catch(_) {
          shirtValue = false
        }
        res()
      })

      await setField('MainContent_Q~1138', '123456789')
      await setField('MainContent_Q~1355',   'United States')

      if(shirtValue) document.getElementById('MainContent_NextButton').click()
    })()
  } else if(/AdditionalItems.aspx/.test(window.location.pathname)) {
    document.getElementById('MainContent_NextButton').click()
  } else if(/Summary.aspx/.test(window.location.pathname)) {
    (async () => {
      if(/\$0\.00/.test(document.getElementById('MainContent_TotalFees').innerText || '')) {
        document.getElementById('MainContent_NextButton').click()
      } else {
        await setField('MainContent_PromoCode', 'DUS20XC')
        await new Promise((res) => {
          document.getElementById('MainContent_ApplyPromoCode').click()
        })
      }
    })()
  } else if(/SaveSuccess.aspx/.test(window.location.pathname)) {
    const findTableRow = (el) => {
      const rows = el.getElementsByTagName('TR')
      let goodRow
      for (let i = 0; i < rows.length; i++) {
        const row = rows[i]
        rowHeaders = row.getElementsByTagName('STRONG')

        for (let hi = 0; hi < rowHeaders.length; hi++) {
          const h = rowHeaders[hi].innerText
          if(/Confirmation Number:/.test(h)) {
            hi = rowHeaders.length + 1
            i = rows.length + 1
            goodRow = row
          }
        }
      }
      if(goodRow) {
        const tables = goodRow.getElementsByTagName("TABLE")
        if(tables.length) {
          return findTableRow(goodRow)
        } else {
          return goodRow
        }
      }
    }
    const tableRow = findTableRow(document)
    if(tableRow) {
      window.prompt("Copy to Clipboard:\n Ctrl+C (Cmd+C for mac), Enter to close this window", tableRow.lastElementChild.innerText.replace(/\s+/g, ''))
    }
  } else if(/start.aspx/.test(window.location.pathname)) {
    const setFields = async (values, fields) => {
      if(values['dusShirtSize']) sessionStorage.setItem('dusShirtSize', values['dusShirtSize']);

      for (let i = 0; i < fields.length; i++) {
        await setField(fields[i], values[fields[i]])
      }

      document.getElementById('MainContent_TandCAccept').checked = true
      document.getElementById('MainContent_NextButton').click()
    }

    const parseDusValues = (ev) => {
      if(!ev.currentTarget.value) return false

      try {
        const value = JSON.parse(ev.currentTarget.value)
        setFields(value.values, value.fields)
      } catch (e) {
        console.log(e, e.stack)
      }
    }

    const div      = document.createElement('DIV'),
          textarea = document.createElement('TEXTAREA'),
          label    = document.createElement('H4');

    label.classList = 'text-center'
    label.style     = "display: block; margin-bottom: .25rem; text-align: center;"
    label.innerText = "PASTE DUS VALUES";

    textarea.rows      = 10
    textarea.className = "form-control"
    textarea.onkeyup  = parseDusValues

    div.appendChild(label);
    div.appendChild(textarea);

    document.body.prepend(div);
    textarea.focus()
  }
})()
