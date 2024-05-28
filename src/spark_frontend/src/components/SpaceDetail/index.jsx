import React from 'react'

const SpaceDetail = (props) => {
  const { info = {} } = props
  return <div>{JSON.stringify(info)}</div>
}

export default SpaceDetail
