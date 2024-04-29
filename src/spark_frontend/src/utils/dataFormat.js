export const responseFormat = (data) => {
  Object.keys(data).forEach((item) => {
    if (typeof data[item] === 'bigint') data[item] = Number(data[item])
    else if (typeof data[item] === 'object' && data[item] === null) {
    } else if (typeof data[item] === 'object' && data[item]._isPrincipal)
      data[item] = data[item].toText()
    else if (typeof data[item] === 'object' && data[item].length === 0)
      data[item] = null
    else if (typeof data[item] === 'object')
      data[item] = responseFormat(data[item])
  })

  return data
}

export const fileToBase64 = (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.readAsDataURL(file)
    reader.onload = () => resolve(reader.result)
    reader.onerror = reject
  })
}

export const timeFormat = (time) => {
  const ftime = parseInt(Number(time) / 1000000)
  const date = new Date(ftime)
  const year = date.getFullYear()
  const month = date.getMonth()
  const day = date.getDate()
  const hour = date.getHours()
  const minute = date.getMinutes()
  const second = date.getSeconds()
  const _time = `${year}-${month + 1}-${day} ${hour}:${minute}:${second}`
  return _time
}
