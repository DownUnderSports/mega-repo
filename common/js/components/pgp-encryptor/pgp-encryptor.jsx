import OpenPGP, { message, key } from 'openpgp'
// import OpenPGP, { HKP, message, key } from 'openpgp'
import getMimeType from './get-mime-type'
import getFileName from './get-file-name'

export { getFileName, getMimeType }

export function canEncryptFile() {
  return !!(
    window.File
    && window.FileReader
    && window.FileList
    && window.Blob
    && window.atob
    && window.btoa
  )
}

let workerStarted = false

function startPGPWorker() {
  OpenPGP.initWorker({ path: '/openpgp.worker.min.js' })
}

export default function PGPEncryptor(io, baseFileName = false, allowUnknown = false) {
  return new Promise(async (res, rej) => {
    try {
      if(!canEncryptFile()) throw new Error('Encryption Not Supported')
      if(!workerStarted) {
        workerStarted = true
        startPGPWorker()
      }

      const mimeType = await getMimeType(io, allowUnknown),
            fileName = getFileName(io.name, mimeType, baseFileName)

      // console.log(io.slice(0, io.size, mimeType))

      io = new File( [ io.slice(0, io.size, mimeType) ], fileName, { type: mimeType } )

      console.log(mimeType, io)

      // const hkp = new HKP()
      // try {
      //   pubKey = await hkp.lookup({ query: '0x97c8926b35ea478cebd9513d70abc561ea13a190' })
      // } catch(_) {
      //   try { hkp.upload(pubKey).catch(function(){}) } catch(_) {}
      // }
      const pubKey = (await import(/* webpackChunkName: "openpgp-public-key" */ './public-key')).default

      const reader = new FileReader()

      reader.onload = async function(ev) {
        var binaryString = ev.target.result
        // const result = btoa(binaryString)
        const cypher = await OpenPGP.encrypt({
          message: message.fromBinary(new Uint8Array(binaryString)),
          // message: message.fromText(result),
          publicKeys: (await key.readArmored(pubKey)).keys,
          armor: false
        })

        const encryptedType = `application/pgp-encrypted+${mimeType.replace('/', '----')}`,
              encryptedFileName = `${fileName}.gpg`,
              encryptedFile = new File(
                [ new Blob([ cypher.message.packets.write() ], { type: encryptedType }) ],
                `${fileName}.gpg`,
                { type: encryptedType }
              )

        res({
          fileName,
          mimeType,
          encryptedType,
          encryptedFile,
          encryptedFileName,
        })
      }

      reader.onerror = function (error) {
        console.log('Error: ', error)
        rej(error)
      }

      reader.readAsArrayBuffer(io)
    } catch (e) {
      return rej(e)
    }
  })
}
