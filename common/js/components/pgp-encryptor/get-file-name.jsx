export default function getFileName(name, mimeType, baseName = '') {
  let extMatch = (mimeType || '').match(/\/([^/]+)/) || []
  if(!(/[^.]\.[^.]/.test(name || ''))) name = `${name || 'unknown'}.${extMatch[1] || 'unknown'}`
  name = name.underscore()
  switch (mimeType) {
    case "image/png":
      return baseName ? `${baseName}.png` : name.replace(/\.[^.]+$/, '.png')
    case "image/bmp":
      return baseName ? `${baseName}.bmp` : name.replace(/\.[^.]+$/, '.bmp')
    case "image/gif":
      return baseName ? `${baseName}.gif` : name.replace(/\.[^.]+$/, '.gif')
    case "image/jpeg":
      return baseName ? `${baseName}.jpg` : name.replace(/\.[^.]+$/, '.jpg')
    case "image/tiff":
      return baseName ? `${baseName}.tif` : name.replace(/\.[^.]+$/, '.tif')
    case "image/x-icon":
      return baseName ? `${baseName}.ico` : name.replace(/\.[^.]+$/, '.ico')
    case "application/pdf":
      return baseName ? `${baseName}.pdf` : name.replace(/\.[^.]+$/, '.pdf')
    case "application/zip":
      return baseName ? `${baseName}.zip` : name.replace(/\.[^.]+$/, '.zip')
    case "application/gzip":
      return baseName ? `${baseName}.gz` : name.replace(/\.[^.]+$/, '.gz')
    // case "application/java":
    //   return baseName ? `${baseName}.class` : name.replace(/\.[^.]+$/, '.class')
    // case "application/illustrator":
    //   return baseName ? `${baseName}.ai` : name.replace(/\.[^.]+$/, '.ai')
    // case "application/postscript":
    //   return baseName ? `${baseName}.aps` : name.replace(/\.[^.]+$/, '.aps')
    default:
      return baseName ? `${baseName}.${name}` : name
  }
}
