export default function migrations(db, oldVersion, newVersion, tx) {
  if((+oldVersion || 0) < 8) {
    db.objectStoreNames.contains('inboundDomesticFlights') && db.deleteObjectStore('inboundDomesticFlights')
  }

  if((+oldVersion || 0) < 10) {
    db.objectStoreNames.contains('users') && db.deleteObjectStore('users');

    db.objectStoreNames.contains('travelerBuses') && db.deleteObjectStore('travelerBuses');
  }
}
