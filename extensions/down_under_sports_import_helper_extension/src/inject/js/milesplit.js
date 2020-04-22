const startingValues = {
  currentEvent: null,
  currentState: false,
  events: [],
  fileName: new Date().getTime(),
  gender: 'M',
  grades: [],
  lastEvent: null,
  originalEvents: [],
  runningMilesplit: false,
  states: [],
  startingPoint: '/'
}

const trimValue = (el) => el.innerHTML.trim();

const goToUrl = (url) => {
  var link = document.createElement("a");
  link.setAttribute("href", url);
  document.body.appendChild(link);
  link.click();
}

const isCurrentDomain = url =>
        new RegExp(window.location.host.replace(/\./g, '\\.')).test(url)

const randomNumber = (min, max) => Math.floor(Math.random() * (Math.max(max || 1, min || 0) - Math.min(max || 1, min || 0) + 1)) + Math.min(max || 1, min || 0)

const spliceRandom = arr => arr.splice(randomNumber(0, arr.length - 1), 1)[0]

const buttonId = 'DUS_IMPORT_BUTTON',
      singleButtonId = 'DUS_IMPORT_BUTTON_SINGLE',
      clearButtonId = 'DUS_CLEAR_ALL_RUNNING',
      stateListWrapperId = 'DUS_STATES_CHECKBOXES'

class ParseMilesplitTables {
  constructor() {
    this.bindFunctions()

    this._domReady().then(this.run)
  }

  async run() {
    this._addClearButton()
    await this._waitFor(randomNumber(2000, 10000))
    await this._loadData()
    this.start()
  }

  async start() {
    const values = await this._get(startingValues)

    // console.log(values, this)
    // await this._waitFor(5000)

    if(values.runningMilesplit === 'createCSV') {
      return this._createCSV()
    } else if(values.runningMilesplit === 'runningCities') {
      return this._getCities();
    } else if(this.mainSection) {
      this._isRunnable(values)
    } else {
      this._checkFourOhFour(values)
    }
  }

  _addClearButton() {
    const clearButton = document.createElement('a');

    clearButton.id = clearButtonId;
    clearButton.innerHTML = 'STOP RUNNING';

    try {
      document.getElementById('content').prepend(clearButton);
    } catch(e) {
      document.body.prepend(clearButton);
    }

    document.addEventListener('click', this._clearCurrent);
  }

  async _clearCurrent(e) {
    if(e.target.id === clearButtonId) {
      clearTimeout(this._runTimeout);
      if(window.confirm('Clear Data?')) return await this._deleteAllData();


      const values = await this._get(null)
      await this._loadData()

      console.log(this);
      console.log(values);
      console.log('currentCity: ', localStorage.getItem('currentCity'));
      console.log('currentGrade: ', localStorage.getItem('currentGrade'));

      document.removeEventListener('click', this._clearCurrent);

      const input = document.createElement('input')

      input.style = "position: fixed; top: 0; left: 0; width: 100%; z-index: 1000"
      const wasRunning = values.runningMilesplit
      input.value = wasRunning
      input.addEventListener('blur', () => {
        this._set({ runningMilesplit: input.value || wasRunning })
      })

      document.body.appendChild(input);

      e.target.innerHTML = 'NEXT EVENT OR AGE, REFRESH TO CONTINUE'
      let cl = (ev) => {
        if(ev.target.id === clearButtonId) {
          document.removeEventListener('click', cl);
          this._yearEventOrCities()
        }
      }
      document.addEventListener('click', cl);
    }
  }

  async _domReady () {
    return this._domReady = this._domReady || new Promise(resolve => {
      if (document.readyState === 'loading') {
        document.addEventListener("DOMContentLoaded", contentLoaded, true);
      } else {
        resolve()
      }

      function contentLoaded() {
        document.removeEventListener("DOMContentLoaded", contentLoaded, true)
        resolve();
      }
    })
  }

  async _loadData() {
    try {
      await this._setAttributes()
      await this._openDB()
      const schools = await this.db.schools.toArray()
      for(const school of schools) {
        this.data[school.url] = school
      }
      return this.data
    } catch (err) {
      await this._waitFor(5000)
      window.location.reload(true)
    }
  }

  bindFunctions() {
    this._addClearButton = this._addClearButton.bind(this)
    this._addElementsToDOM = this._addElementsToDOM.bind(this)
    this._checkFourOhFour = this._checkFourOhFour.bind(this)
    this._clearCurrent = this._clearCurrent.bind(this)
    this._createCSV = this._createCSV.bind(this)
    this._deleteAllData = this._deleteAllData.bind(this)
    this._domReady = this._domReady.bind(this)
    this._downloadTable = this._downloadTable.bind(this)
    this._freshStart = this._freshStart.bind(this)
    this._get = this._get.bind(this)
    this._getCities = this._getCities.bind(this)
    this._getOptionsFromEventEl = this._getOptionsFromEventEl.bind(this)
    this._getStatesList = this._getStatesList.bind(this)
    this._isRunnable = this._isRunnable.bind(this)
    this._loadData = this._loadData.bind(this)
    this._nextEvent = this._nextEvent.bind(this)
    this._nextGender = this._nextGender.bind(this)
    this._nextState = this._nextState.bind(this)
    this._openDB = this._openDB.bind(this)
    this._parseTable = this._parseTable.bind(this)
    this._putAll = this._putAll.bind(this)
    this._saveData = this._saveData.bind(this)
    this._set = this._set.bind(this)
    this._setAttributes = this._setAttributes.bind(this)
    this._shiftGrade = this._shiftGrade.bind(this)
    this._startRun = this._startRun.bind(this)
    this._waitFor = this._waitFor.bind(this)
    this.run = this.run.bind(this)
    this.start = this.start.bind(this)
  }

  async _setAttributes() {
    this.data = {}
    this._noRun = ['usa', 'os', 'pr', 'leaders', '4x100m', '4x200m', '4x400m', '4x800m', 'flo50', 'smr']
    this.currentGrade = localStorage.getItem('currentGrade')
    this.gradeOptions = ['junior', 'sophomore', 'freshman'/*, '8th-grade'*/]
    this.db = new Dexie('MilesplitDB - Down Under Sports')
    this.db.version(1).stores({
      schools: 'url'
    });

    const values = await this._get(startingValues)

    for(const k in startingValues) {
      this[k] = values[k]
    }
  }

  async _openDB() {
    this._isOpen = this._isOpen || new Promise(async (r, j) => {
      try {
        await this.db.open()
        r()
      } catch(err) {
        this._isOpen = false
        j(err)
      }
    })
  }

  _putAll(clear = false) {
    const transactions = [];
    for(const school of Object.values(this.data)) {
      transactions.push({
        ...school,
        data: clear ? [] : school.data || [],
      })
    }
    return transactions;
  }

  async _saveData(shouldClear = false) {
    await this._openDB()

    return this.db.transaction('rw', this.db.schools, () => {
      return this.db.schools.bulkPut(this._putAll(shouldClear))
    })
  }

  async _createCSV() {
    const headers = [
            'NameAcquisition',
            'FirstName',
            'LastName',
            'Gender',
            'YearGrad',
            'Stats',
            'State',
            'Sport',
            'School',
            'City'
          ],
          data = [ headers ];

    let failed, blobdata, csvLink

    const values = await this._get({ fileName: new Date().getTime() })

    try {
      for (const school of Object.values(this.data)) {
        for(const athlete of school.data) {
          const row = []
          athlete['City'] = school.city;
          for(const header of headers) {
            row.push(
              (
                athlete.mileSplitProfile
                && (header === 'Stats')
              ) ? `${athlete[header]}\n\n${athlete.mileSplitProfile}`
                : String(athlete[header] || '')
            )
          }
          data.push(row)
        }
      }

      const csv = data.map(row => row.map(value => `"${value.replace(/"/g, `""`)}"`).join(',')).join("\n")

      blobdata = new Blob([csv.trim()],{type : 'text/csv'});
      csvLink = document.createElement("a");
      csvLink.setAttribute("href", window.URL.createObjectURL(blobdata));
      csvLink.setAttribute("download", "milesplit_data_" + values.fileName + ".csv");
      document.body.appendChild(csvLink);
      csvLink.click();
    } catch (err) {
      failed = true
      console.error(err)
      console.info(csvLink, values.fileName, blobdata);
    }

    if(!failed) {
      await this._waitFor(60 * 1000)

      await this._saveData(true)

      localStorage.removeItem('currentGrade');

      await this._set({ runningMilesplit: 'nextGender' })
      await this._deleteLocalKeys();
      goToUrl((await this._get('startingPoint')).startingPoint)
    }
  }

  _deleteLocalKeys() {
    var i, storageKeys = ['currentGrade', 'currentCity'];
    for(i = 0; i < storageKeys.length; i++) localStorage.removeItem(storageKeys[i]);
  }

  async _deleteAllData() {
    this._deleteLocalKeys();
    const values = await this._get(null)

    console.log(values);

    await this._loadData()
    await this._saveData(true)

    return await new Promise((r, j) => {
      chrome.storage.local.clear(() => {
        const err = this._hasError()
        if(err) return j(err)

        r()
      });
    })
  }

  async _freshStart(state) {
    const { originalEvents = [] } = await this._get({ originalEvents: [] }),
          elEvents = this._getOptionsFromEventEl(true),
          ogEvents = (originalEvents && originalEvents.length)
            ? originalEvents.slice(0)
            : elEvents,
          options = ogEvents.filter(v => (this.eventEl.value !== v) && elEvents.includes(v)),
          seasonVal = this.seasonEl.value,
          levelVal = this.levelEl.value;

    this._deleteLocalKeys();

    await this._set({
      events: options,
      grades: this.gradeOptions.slice(0),
      fileName: state + '_' + levelVal + '_' + seasonVal
    })

    if(!!this.gradeEl.value) {
      this._dispatchEvent(this.gradeEl, '');
      return false
    } else if(!ogEvents.includes(this.eventEl.value)) {
      console.log('event not found', ogEvents, this.eventEl.value)

      return await new Promise(res => {
        setTimeout(() => {
          this._dispatchEvent(this.eventEl, spliceRandom(options));
          return res(false)
        }, 60 * 1000)
      })
    }

    return true;
  }

  _hasError() {
    const lastError = chrome.runtime.lastError
    if(lastError) {
      console.error("CHROME RUNTIME ERROR", chrome.runtime.lastError)
      chrome.runtime.lastError = null
    }

    return lastError;
  }

  _dispatchEvent(el, value) {
    el.value = value;
    return setTimeout(function() {
      el.dispatchEvent(new Event('change', { 'bubbles': true }))
    }, 1000)
  }

  _set(args) {
    return new Promise((r, j) => {
      chrome.storage.local.set(args, () => {
        const err = this._hasError()
        if(err) return j(err)

        r()
      })
    })
  }

  _get(options, cb) {
    return new Promise((r, j) => {
      chrome.storage.local.get(options, currentValues => {
        const err = this._hasError()
        if(err) return j(err)

        r(currentValues)
      })
    })
  }

  _getStatesList() {
    return !this.stateEl
      ? []
      : Array.apply(null, this.stateEl.options)
          .map(option => String(option.value))
          .filter(value => !this._noRun.includes(value.toLowerCase()))
  }

  _toggleStatesList(direction) {
    console.log('toggle states list: ', direction);

    for(const input of document.querySelectorAll('input[name=DUS_STATE_CHECKBOX]')) {
      input.checked = !!direction;
    }

    return !!direction;
  }

  _getCheckedStates() {
    return Array.from(
      document.querySelectorAll('input[name=DUS_STATE_CHECKBOX]:checked')
    )
    .filter(el => !!el)
    .map(el => el.value)
  }

  _getOptionsFromEventEl(fullList = false) {
    return Array.apply(null, this.eventEl.options)
      .map(option => option.value)
      .filter(value =>
        value
        && !this._noRun.includes(value.toLowerCase())
        && (
          fullList
          || value !== this.eventEl.value
        )
      )
  }

  async _getCities() {
    const values = await this._get('startingPoint')

    const massChecked = localStorage.getItem('massTeamPage')

    if (massChecked !== 'done') {
      if(!massChecked) {
        for(const school in this.data) {
          try {
            if(/teams/.test(school)) {
              localStorage.setItem('massTeamPage', 'redirecting')
              goToUrl(school.split('/').filter(l => !/^[0-9]+$/.test(l)).join('/'))
            }
          } catch(err) {
            console.error(err)
          }
        }
      }

      for(const row of document.querySelectorAll('#content table.teams tbody tr')) {
        let key, value

        for(const cell of row.querySelectorAll('td')) {
          const schoolLink = cell.querySelector('a')
          if(schoolLink) {
            key = schoolLink.href.replace(/(.*\/[0-9]+)\-.*/, "$1");
          } else {
            if(cell.innerHTML.toLowerCase().indexOf('usa') !== -1){
              value = cell.innerText.split(',')[0].trim();
              value = /^[A-Z]{2,3}$/.test(value) ? 'unknown' : value
            }
          }
          if(key && value) break
        }

        if(!!key && !!value && !!this.data[key]) {
          foundSomething = true;
          this.data[key]['visited'] = true;
          this.data[key]['city'] = value;
        }
      }

      await this._saveData();

      localStorage.setItem('massTeamPage', 'done')
    }

    try{
      await this._scrollIntoViewIfNeeded(document.querySelector('footer'))
    } catch(err) {
      console.error(err)
      await this._waitFor(5000)
    }


    const currentCity = localStorage.getItem('currentCity')

    if(currentCity) {
      this.data[currentCity]['visited'] = true;
      this.data[currentCity]['city'] = 'unknown';

      const spans = document.querySelectorAll('header.profile .teamInfo span');

      for(const span of spans) {
        if(span.innerHTML.toLowerCase().indexOf('usa') !== -1) {
          const city = span.innerHTML.split(',')[0].trim()

          this.data[currentCity]['city'] = /^[A-Z]{2,3}$/.test(city)
            ? 'unknown'
            : city

          break
        }
      }

      await this._saveData();
    }

    const startingPoint = String(values.startingPoint || '');

    for(const school of Object.values(this.data)) {
      if(!school.visited) {
        if(isCurrentDomain(school.url) && isCurrentDomain(startingPoint)) {
          localStorage.setItem('currentCity', school.url);
          return goToUrl(school.url);
        } else if(currentCity) {
          this.data[currentCity]['visited'] = true;
          this.data[currentCity]['city'] = 'unknown';

          await this._saveData();
        }
      }
    }

    localStorage.removeItem('currentCity');
    localStorage.removeItem('massTeamPage');

    await this._set({ runningMilesplit: 'createCSV' })

    goToUrl(startingPoint)
  }

  async _shiftGrade(grades) {
    let grade = spliceRandom(grades),
        noVal = true

    const findGrade = () =>
            noVal = !Array.from(this.gradeEl.options)
                          .some(option => option.value === grade);

    while(findGrade() && grades.length) grade = spliceRandom(grades);

    if(noVal) return 'noGrades';

    await this._set({ grades })

    localStorage.setItem('currentGrade', this.currentGrade = grade);
    this._dispatchEvent(this.gradeEl, this.currentGrade);
    return this.currentGrade
  }

  _checkFourOhFour({ runningMilesplit, lastEvent }) {
    if(runningMilesplit === 'nextEvent') {
      Array.from(document.querySelectorAll('h1')).some(header => {
        return /not found/.test(header.innerText.toLowerCase()) && !!(
          this._waitFor(5000).then(async () => {
            await this._set({
              runningMilesplit: 'nextEvent',
              currentEvent: lastEvent
            })

            const url = window.location.href.split('?');

            goToUrl(url[0].replace(/(.*\/)(.*)/, '$1') + '?' + (url[1] || ''))
          })
        )
      })
    }
  }

  async _isRunnable(values) {
    if(values.runningMilesplit === 'true') return this._parseTable();
    else if(values.runningMilesplit === 'nextEvent') return this._nextEvent(values)
    else if(values.runningMilesplit === 'nextGender') return this._nextGender(values)
    else if (values.runningMilesplit === 'nextState') return this._nextState(values)

    if(await this._freshStart(this.stateEl.value)) this._addElementsToDOM();
  }

  async _yearEventOrCities() {
    const { grades, events } = await this._get({grades: [], events: []})

    if(!grades.length && !events.length) {
      localStorage.removeItem('currentCity');
      localStorage.removeItem('massTeamPage');
      await this._set({runningMilesplit: 'runningCities'})
      return this._getCities()
    } else if (await this._shiftGrade(grades) !== 'noGrades') {
      return console.log('switching grades')
    }

    await this._set({runningMilesplit: 'nextEvent'})
    this._dispatchEvent(this.gradeEl, '');
  }

  async _nextEvent({ currentEvent, events = [] }) {
    currentEvent = currentEvent || spliceRandom(events)

    if(this.eventEl.value !== currentEvent) {
      await this._set({
        events,
        currentEvent,
        lastEvent: this.eventEl.value
      })

      this.eventEl.value = currentEvent;
      return this._dispatchEvent(this.eventEl, currentEvent);
    }

    await this._set({
      grades: this.gradeOptions.slice(0),
      runningMilesplit: 'true',
      currentEvent: null,
      lastEvent: this.eventEl.value
    })

    return this._yearEventOrCities()
  }

  async _nextGender({ gender = 'M' }) {
    if(gender === 'F') {
      console.log('completed women');
      await this._set({ runningMilesplit: 'nextState', gender: 'M' })
      return this._dispatchEvent(this.levelEl, 'high-school-boys');
    }

    const levelVal = this.levelVal
    if(levelVal.some(v => /^(BOYS|MEN)$/.test(v))) {
      return this._dispatchEvent(this.levelEl, 'high-school-girls');
    }

    if(await this._freshStart(this.stateEl.value)) this._startRun(false, 'F');
  }

  async _nextState({ currentState, states = [], startingPoint = '/' }) {
    this._deleteLocalKeys();
    if(this.levelEl.value !== 'high-school-boys') return this._dispatchEvent(this.levelEl, 'high-school-boys');
    else if(this._hasError()) return;
    else if(currentState !== this.stateEl.value) {
      if(states.length > 0) {
        currentState = spliceRandom(states);

        await this._set({
          currentState,
          states
        })

        return this._dispatchEvent(this.stateEl, currentState);
      } else {
        await this._deleteAllData();
        return goToUrl(startingPoint)
      }
    }

    if(await this._freshStart(currentState)) this._startRun();
  }

  async _startRun(wrongState, gender) {
    await this._saveData(true)

    await this._set({
      runningMilesplit: wrongState ? 'nextState' : 'true',
      startingPoint: window.location.href,
      currentState: false,
      gender: gender ? gender : 'M',
      lastEvent: this.eventEl ? this.eventEl.value : null
    });

    return this._parseTable()
  }

  _waitFor(time) {
    return new Promise(r => this._runTimeout = setTimeout(r, time))
  }

  // _scrollIntoViewIfNeeded(target) {
  //   const scrollPromise = new Promise(resolve => {
  //     let scrollTimeout, scrollListener;
  //
  //     scrollListener = () => {
  //       clearTimeout(scrollTimeout);
  //       scrollTimeout = setTimeout(() => {
  //         window.removeEventListener('scroll', scrollListener)
  //         resolve()
  //       }, 1000);
  //     }
  //
  //     window.addEventListener('scroll', scrollListener);
  //     scrollListener()
  //   })
  //
  //   var rect = target.getBoundingClientRect();
  //   if (rect.bottom > window.innerHeight) {
  //     target.scrollIntoView({ behavior: "smooth", block: "start", inline: "nearest" })
  //   } else if(rect.top < 0) {
  //     target.scrollIntoView()
  //   }
  //
  //   return scrollPromise
  // }

  async _scrollIntoViewIfNeeded(target) {
    const scrollPromise = () => new Promise(resolve => {
      let scrollTimeout, scrollListener;

      scrollListener = () => {
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(() => {
          window.removeEventListener('scroll', scrollListener)
          resolve()
        }, randomNumber(randomNumber(200, 1000), randomNumber(750, 2000)));
      }

      window.addEventListener('scroll', scrollListener);
      scrollListener()
    })

    while(target.getBoundingClientRect().top > window.innerHeight) {
      const pr = scrollPromise()
      window.scrollBy({ top: 16 * randomNumber(13, 27), behavior: 'smooth' })
      await pr
      // row.scrollIntoView({ behavior: "smooth", block: "start", inline: "nearest" })
    }

    while(target.getBoundingClientRect().bottom < 0) {
      const pr = scrollPromise()
      window.scrollBy({ top: -16 * randomNumber(13, 27), behavior: 'smooth' })
      await pr
      // row.scrollIntoView({ behavior: "smooth", block: "start", inline: "nearest" })
    }

    return target
  }

  _sortStats(a, b) {
    try {
      const [pA] = /^[0-9]+/.exec(String(a || '')),
            [pB] = /^[0-9]+/.exec(String(b || ''))
      return (+pA > +pB)
        ? 1
        : (+pA < +pB)
          ? -1
          : 0
    } catch(err) {
      return /^[0-9]/.test(a)
        ? -1
        : /^[0-9]/.test(b)
          ? 1
          : [ a, b ].sort()[0] === a
            ? -1
            : 1
    }
  }

  async _parseRow({ row, gender, state, sport, event }) {
    try {
      await this._scrollIntoViewIfNeeded(row)

      let nameHolder = row.querySelector('td.name .athlete a'),
          name = trimValue(nameHolder).split(' '),
          mileSplitProfile = nameHolder.href || '',
          place = trimValue(row.querySelector('td.meet > .meet em')).split(' ')[0],
          meet = trimValue(row.querySelector('td.meet > .meet a')),
          time = trimValue(row.querySelector('td.time')),
          schoolLink = row.querySelector('td.name .team a').href,
          stats = `${place}  Place - ${meet} ${event} (${time})`.replace(/^\s*Place - /, '');

      if(!this.data[schoolLink]) {
        this.data[schoolLink] = {
          url: schoolLink,
          city: '',
          visited: false,
          data: []
        };
      }

      let datum = mileSplitProfile
        ? this.data[schoolLink].data
            .findIndex(a => a.mileSplitProfile === mileSplitProfile)
        : -1

      if(datum !== -1) {
        try {
          datum = this.data[schoolLink].data[datum]
          datum.Stats = [...datum.Stats.split(`\n\n`), stats]
                          .map(v => v.replace(/^\s*Place - /, ''))
                          .filter((v, i, s) => v && (s.indexOf(v) === i))
                          .sort(this._sortStats)
                          .join(`\n\n`)
        } catch (err) {
          console.error(err)
          console.log(datum, schoolLink, this.data)
          throw err
        }
      } else {
        datum = {
          NameAcquisition: 'milesplit.com',
          FirstName: name[0],
          LastName: name[1],
          Gender: gender,
          YearGrad: trimValue(row.querySelector('td.year')),
          Stats: stats,
          State: state(row),
          Sport: sport,
          School: trimValue(row.querySelector('td.name .team a')),
          City: '',
          mileSplitProfile
        }
      }

      this.data[schoolLink].data.push(datum)
    } catch (err) {
      console.error(err)
    }
  }

  async _extractPageInfo() {
    if(!this.parsingAllowed) return { skip: true };

    var accuracy = document.getElementById('ddAccuracy');

    if((!!accuracy) && (accuracy.value !== 'all')) {
      this._dispatchEvent(accuracy, 'all');
      return false
    }

    const values = await this._get({ gender: 'M' })

    const rows = Array.from(this.table.querySelectorAll('tbody tr')),
          event = this.currentEventOption,
          level = this.levelVal,
          sport = this.sport,
          stateVal = this.stateEl && this.stateEl.value,
          state = (
            stateVal === 'usa'
            ? function(row){ return trimValue(row.querySelector('td.name .team .state')) }
            : function() { return stateVal }
          ),
          gender = (level.includes('BOYS') || level.includes('MEN')) ? 'M' : 'F'

    if(gender !== values.gender) {
      return this._dispatchEvent(
        this.levelEl,
        (values.gender === 'M')
          ? 'high-school-boys'
          : 'high-school-girls'
      );
    }

    if(this._noRun.includes(event.toLowerCase())) return { skip: true };

    return {
      rows,
      gender,
      state,
      sport,
      event
    }
  }

  async _parseTable() {
    const { rows, gender, state, sport, event, skip } = await this._extractPageInfo()

    if(skip) return this._yearEventOrCities()

    for(const row of rows) await this._parseRow({ row, gender, state, sport, event })

    await this._saveData()

    const nextPage = this.mainSection.querySelector('.pagination a.next')

    if(nextPage) {
      await this._scrollIntoViewIfNeeded(nextPage)
      return nextPage.click()
    }

    this._yearEventOrCities();
  }

  _addElementsToDOM() {
    if(this.levelEl && this.levelEl.value !== 'high-school-boys') {
      return this._dispatchEvent(this.levelEl, 'high-school-boys');
    }

    let toggleTimeout

    const checkAllButton = document.createElement('button'),
          checkNoneButton = document.createElement('button'),
          newButton = document.createElement('a'),
          single = document.createElement('a'),
          stateListWrapper = document.createElement('div'),
          statesList = this._getStatesList();

    stateListWrapper.id = stateListWrapperId;
    stateListWrapper.innerHTML = '<br/>';

    checkAllButton.innerText = 'Check All';
    checkNoneButton.innerText = 'Check None';

    stateListWrapper.prepend(checkAllButton);
    stateListWrapper.prepend(checkNoneButton);

    checkAllButton.addEventListener('click', () => {
      clearTimeout(toggleTimeout);
      toggleTimeout = setTimeout(() => this._toggleStatesList(true), 1000);
    })

    checkNoneButton.addEventListener('click', () => {
      clearTimeout(toggleTimeout);
      toggleTimeout = setTimeout(() => this._toggleStatesList(false), 1000);
    })

    for(var i = 0; i < statesList.length; i++) {
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.name = 'DUS_STATE_CHECKBOX';
      checkbox.value = statesList[i];
      checkbox.checked = false;

      const label = document.createElement('label');
      label.innerText = statesList[i];
      label.prepend(checkbox);

      stateListWrapper.appendChild(label);

      if(i < (statesList.length - 1)) {
        const span = document.createElement('span');
        span.innerHTML = '&nbsp;|&nbsp;'
        stateListWrapper.appendChild(span);
      }
    }

    newButton.id = buttonId;
    newButton.innerHTML = 'Download Table';

    single.id = singleButtonId;
    single.innerHTML = 'Download Table (THIS STATE ONLY)';
    // single.setAttribute('data-state', state);
    if(this.table) {
      this.table.parentElement.prepend(stateListWrapper);
      this.table.parentElement.prepend(newButton);
      this.table.parentElement.prepend(single);
    } else{
      this.mainSection.appendChild(stateListWrapper);
      this.mainSection.appendChild(newButton);
      this.mainSection.appendChild(single);
    }

    document.addEventListener('click', this._downloadTable);
  }

  async _downloadTable(ev) {
    if((ev.target.id === buttonId) || (ev.target.id === singleButtonId)) {
      ev.preventDefault();
      ev.stopPropagation();
      document.removeEventListener('click', this._downloadTable);

      const singleButton = ev.target.id === singleButtonId,
            checkedStates = singleButton
              ? this.stateEl
                ? [ this.stateEl.value ]
                : []
              : this._getCheckedStates(),
            { events = [] } = await this._get({ events: [] }),
            eventList = this._getOptionsFromEventEl(),
            currentEvents = events || [],
            maxLength = Math.min(currentEvents.length, eventList.length)

      let custom = currentEvents.length !== eventList.length

      if(!custom) {
        for(let i = 0; i < maxLength; i++) {
          custom = !eventList.includes(currentEvents[i])
          if(custom) break;
        }
      }

      const states = singleButton
                    ? []
                    : !this.stateEl
                      ? checkedStates
                      : checkedStates.filter(val => val !== this.stateEl.value)

      await this._set({
        states,
        events: this._getOptionsFromEventEl(),
        originalEvents: custom ? this._getOptionsFromEventEl(true) : []
      })

      return this._startRun(!(this.stateEl && checkedStates.includes(this.stateEl.value)))
    }
  }

  get table() {
    return this._table = this._table || document.querySelector('#eventRankings table, #rankingsLeaders table')
  }

  get currentGradeOption() {
    return ((this.gradeEl || {}).value || '').toLowerCase()
  }

  get currentGradeAllowed() {
    return this.gradeOptions.includes(this.currentGradeOption)
  }

  get parsingAllowed() {
    return this.currentGrade
    && this.table
    && this.currentGradeAllowed
  }

  get currentEventOption() {
    return ((this.eventEl || {}).value || '').toUpperCase()
  }

  get eventEl() {
    return this._eventEl = this._eventEl || document.getElementById('ddEvent')
  }

  get gradeEl() {
    return this._gradeEl = this._gradeEl || document.getElementById('ddGrade')
  }

  get levelEl() {
    return this._levelEl = this._levelEl || document.getElementById('ddLevel')
  }

  get levelVal() {
    return ((this.levelEl || {}).value || '').toUpperCase().split('-')
  }

  get stateEl() {
    return this._stateEl = this._stateEl || document.getElementById('ddState');
  }

  get seasonEl() {
    return this._seasonEl = this._seasonEl || document.getElementById('ddSeason');
  }

  get sport() {
    return ((this.seasonEl || {}).value === 'cross-country')
      ? 'XC'
      : 'TF'
  }

  get mainSection() {
    return this._mainSection = this._mainSection || document.querySelector('#eventRankings, #rankingsLeaders')
  }
}

new ParseMilesplitTables()
