import React, { Component } from 'react'
import { Objected } from 'react-component-templates/helpers';
import { DisplayOrLoading, Link } from 'react-component-templates/components';
import { currencyFormat } from 'react-component-templates/form-components';
import FieldsFromJson from 'common/js/components/fields-from-json';
import JellyBox from 'load-awesome-react-components/dist/square/jelly-box'
import onFormChange, { deleteValidationKeys } from 'common/js/helpers/on-form-change';
import { emailRegex } from 'common/js/helpers/email';

export default function PaymentForm () {
  return (
    <div className="Site-special-offer red">
      <div className="ribbon-wrapper">
        <h3 className="ribbon">
          <strong className="ribbon-inner">
            Online Payments Have Been Disabled Until Further Notice
          </strong>
        </h3>
      </div>
    </div>
  )
}
