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

export const formatPostTree = (list) => {
  const map = new Map()
  list.forEach((item) => {
    map.set(item.id, { ...item, key: item.id, children: [] })
  })

  // 定义一个递归函数，用于构建每个节点的子树
  function buildTree(node) {
    list.forEach((item) => {
      if (item.pid === node.id) {
        const childNode = map.get(item.id)
        // 递归构建子树，并添加到当前节点的children中
        node.children.push(buildTree(childNode))
      }
    })
    return node
  }

  // 过滤出根节点并递归构建整棵树
  return list
    .filter((item) => item.pid === 0)
    .map((rootNode) => buildTree(map.get(rootNode.id)))
}

export const formatICPAmount = (num) => {
  const _num = num || 0
  return (_num * Math.pow(10, -8)).toFixed(4)
}

export const formatCyclesAmount = (num) => {
  const _num = num || 0
  return `${(_num / Math.pow(10, 12)).toFixed(3)} T`
}

export const formatOmitId = (id) => {
  if (!id) return '-'
  if (id.length <= 8) return id
  return id.substr(0, 5) + '...' + id.substr(-3)
}
