import React, { Component } from 'react'
import EncryptedFile from 'common/js/components/encrypted-file'

export default class EncryptedFileTestPage extends Component {
  render(){
    return <EncryptedFile showInfo accept="image/*,application/pdf"/>
  }
}
