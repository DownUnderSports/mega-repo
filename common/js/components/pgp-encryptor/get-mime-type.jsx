// function getDocType(io) {
//   throw new Error("Invalid File Type")
// }
//
// function getZipType(io) {
//   const match = (io.name || '').match(/\.([^.]+)$/) || []
//   switch (match[1] || '') {
//     case expression:
//     case "zip":
//       return "application/zip"
//     case "jar":
//       return "application/java-archive"
//     case "odt":
//       return "application/vnd.oasis.opendocument.text"
//     case "ods":
//       return "application/vnd.oasis.opendocument.spreadsheet"
//     case "odp":
//       return "application/vnd.oasis.opendocument.presentation"
//     case "odg":
//       return "application/vnd.oasis.opendocument.graphics"
//     case "odc":
//       return "application/vnd.oasis.opendocument.chart"
//     case "odf":
//       return "application/vnd.oasis.opendocument.formula"
//     case "odi":
//       return "application/vnd.oasis.opendocument.image"
//     case "odm":
//       return "application/vnd.oasis.opendocument.text-master"
//     case "odb":
//       return "application/vnd.oasis.opendocument.database"
//     case "docx":
//       return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
//     case "xlsx":
//       return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
//     case "pptx":
//       return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
//     case "vsdx":
//       return "application/vnd.ms-visio.drawing.main+xml"
//     case "apk":
//       return "application/vnd.android.package-archive"
//     case "aar":
//       return "application/java-archive"
//     default:
//       throw new Error("Invalid File Type")
//   }
// }

export default function getMimeType(io, allowUnknown = false) {
  return new Promise(async (res, rej) => {
    var reader = new FileReader()
    reader.onloadend = function(ev) {
      try {
        var arr = new Uint8Array(ev.target.result)
        var header = ""
        for(var i = 0; i < arr.length; i++) {
          header += arr[i].toString(16)
        }

        // switch (header.slice(0, 8)) {
        switch (header) {
          case "89504e47":
            return res("image/png")
          case "47494638":
            return res("image/gif")
          case "4949002A":
          case "49492A00":
            return res("image/tiff")
          case "00000100":
            return res("image/x-icon")
          case "25504446":
            // if(/\.ai$/.test(io.name || '')) return res("application/illustrator")
            if(/\.ai$/.test(io.name || '')) throw new Error("Invalid File Type")
            return res("application/pdf")
          case "52494646":
            return res("video/avi")
          case "504b34":
            return res("application/zip")
          case "1f8b88":
            return res("application/gzip")
          case "cafebabe":
            throw new Error("Invalid File Type")
            // return res("application/java")
          case "504b0304":
            throw new Error("Invalid File Type")
            // return res(getZipType(io))
          default:
            switch (header.slice(0, 6)) {
              case "ffd8ff":
                return res("image/jpeg")
              default:
                switch(header.slice(0, 4)) {
                  case "424d":
                    return res("image/bmp")
                  case "4949":
                    return res("image/tiff")
                  case "2521":
                    return res("application/postscript")
                  default:
                    switch (header.slice(0, 16)) {
                      case "d0cf11e0a1b11ae1":
                        throw new Error("Invalid File Type")
                        // return res(getDocType(io))
                      default:
                        if(!allowUnknown) throw new Error("Invalid File Type")
                        switch (io.type || 'undefined') {
                          case "application/pdf":
                          case "application/java":
                          case "application/illustrator":
                          case "application/postscript":
                          case "video/avi":
                          case "video/x-troff-msvideo":
                          case "video/msvideo":
                          case "video/x-msvideo":
                          case "image/png":
                          case "image/gif":
                          case "image/jpg":
                          case "image/jpeg":
                          case "image/pjpeg":
                          case "image/pjpg":
                          case "image/tiff":
                          case "image/tif":
                          case "application/zip":
                          case "application/gzip":
                          case "application/java-archive":
                          case "application/vnd.oasis.opendocument.text":
                          case "application/vnd.oasis.opendocument.spreadsheet":
                          case "application/vnd.oasis.opendocument.presentation":
                          case "application/vnd.oasis.opendocument.graphics":
                          case "application/vnd.oasis.opendocument.chart":
                          case "application/vnd.oasis.opendocument.formula":
                          case "application/vnd.oasis.opendocument.image":
                          case "application/vnd.oasis.opendocument.text-master":
                          case "application/vnd.oasis.opendocument.database":
                          case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
                          case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
                          case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
                          case "application/vnd.ms-visio.drawing.main+xml":
                          case "application/vnd.android.package-archive":
                          case "undefined":
                            throw new Error("Invalid File Type")
                          default:
                            return res((io.type || '').toLowerCase())
                        }
                    }
                }
            }

        }
      } catch(e) {
        rej(e)
      }
    }

    reader.onerror = rej

    // reader.readAsArrayBuffer(io.slice(0, 8))
    reader.readAsArrayBuffer(io.slice(0, 4))
  })
}
