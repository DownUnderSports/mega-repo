var observeDOM = (function(){
  var MutationObserver = window.MutationObserver || window.WebKitMutationObserver,
      eventListenerSupported = window.addEventListener;

  return function(obj, callback){
    if( MutationObserver ){
      // define a new observer
      var obs = new MutationObserver(function(mutations, observer){
        if( mutations[0].addedNodes.length || mutations[0].removedNodes.length ) callback();
      });
      // have the observer observe foo for changes in children
      obs.observe( obj, { childList:true, subtree:true });
    }
    else if( eventListenerSupported ){
      obj.addEventListener('DOMNodeInserted', callback, false);
      obj.addEventListener('DOMNodeRemoved', callback, false);
    }
  };
})();

(function(){
  var mainEl,
      findMainDom,
      inputEl,
      values,
      parseValues;
  parseValues = function parseValues(ev) {
    if(ev.target.value) {
      try {
        values = JSON.parse(ev.target.value)
        Object.keys(values).map((k, i) => {
          let el = document.querySelector('.visaRequestForm [name="' + k + '"]')
          if(el) {
            if(el.type === 'radio') {
              el = document.querySelector('.visaRequestForm [name="' + k + '"][value="' + values[k] + '"]')
              if(el) {
                el.checked = true
                try { el.click() } catch(_) {}
              }
            } else {
              el.value = values[k]
            }
          }
        })
      } catch (err) {
        console.log(err)
      }
      ev.target.value = ''
    }
  }
  findMainDom = function findMainDom() {
    mainEl = document.getElementById('e2search_layout_id') || document.getElementById('e1search_layout_id')
    if(!mainEl) return setTimeout(findMainDom, 1000);

    observeDOM(mainEl, (function(){
      var setElementsForAutofill = function(){
        console.log('dom changed');
        if(document.querySelector('.visaRequestForm')) {
          if(!inputEl) {
            inputEl = document.createElement('TEXTAREA');
            inputEl.cols = 50;
            inputEl.rows = 10;
            inputEl.style.marginBottom = '50px';
            (
              document.getElementById('e2tools_ausvisaapp')
              || document.getElementById('e1tools_ausvisaapp')
            ).appendChild(inputEl);
            inputEl.addEventListener('paste', parseValues);
            inputEl.addEventListener('change', parseValues);
            inputEl.addEventListener('keyup', parseValues);
          }
        }
      }
      var called
      return function(){
        if(called) {
          clearTimeout(called)
          called = void(0)
        }
        called = setTimeout(setElementsForAutofill, 500)
      }
    })());
  }
  findMainDom()
})();
// {
//   "TYPE_OF_TRAVEL": "T",
//   "CRIMINAL_CONVICTION": "N",
//   "CITIZEN_OTH_COUNTRIES": "N",
//   "CITIZEN_COUNTRY_1": "",
//   "CITIZEN_COUNTRY_2": "",
//   "CITIZEN_COUNTRY_3": "",
//   "COUNTRY_OF_BIRTH": "United States of America (USA)",
//   "EMAIL": "mail@downundersports.com",
//   "NATIONALITY": "UNITED STATES OF AMERICA (USA)",
//   "HOME_PHONE_NUMBER": "7534732",
//   "HOME_PHONE_AREA": "435",
//   "HOME_PHONE_COUNTRYCODE": "1",
//   "NATIONAL_IDENTITY_NUMBER": "",
//   "COUNTRY_OF_BIRTH": "United States of America (USA)",
//   "EXPIRATION_DATE": "09MAY28",
//   "DATE_OF_BIRTH": "13NOV1999",
//   "DATE_OF_ISSUE": "10MAY18",
//   "SEX": "F",
//   "ISSUING_AUTHORITY": "United States Department of State",
//   "ISSUING_COUNTRY": "USA",
//   "APPLICANT_ALIAS": "N",
//   "HOME_ADDRESS": "1755 N 400 E Ste 201\nNorth Logan, UT 84321",
//   "GIVEN_NAMES": "HAPPY",
//   "PASSPORT_NUMBER": "123456789",
//   "LAST_NAME": "TRAVELER"
// }
