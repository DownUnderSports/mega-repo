# encoding: utf-8
# frozen_string_literal: true

require_dependency 'sport'

class Sport
  # == Constants ============================================================
  REPS = {
    'BB' => {
      name: 'Lynda',
      phone: '435-774-4126',
      email: 'lynda@downundersports.com',
      him_her: 'her'
    }.freeze,
    'CH' => {
      name: 'Nick',
      phone: '435-774-4123',
      email: 'nick@downundersports.com',
      him_her: 'him'
    }.freeze,
    'FB' => {
      name: 'Nick',
      phone: '435-774-4123',
      email: 'nick@downundersports.com',
      him_her: 'him'
    }.freeze,
    'GF' => {
      name: 'Daniel',
      phone: '435-774-4118',
      email: 'daniel@downundersports.com',
      him_her: 'him'
    }.freeze,
    'TF' => {
      multiple: true,
      reps: [
        {
          name: 'Sherrie',
          phone: '435-774-4121',
          email: 'sherrie@downundersports.com',
          him_her: 'her'
        }.freeze,
        {
          name: 'Kim',
          phone: '435-774-4113',
          email: 'kim@downundersports.com',
          him_her: 'her'
        }.freeze
      ].freeze,
      name: 'Sherrie',
      phone: '435-774-4121',
      email: 'sherrie@downundersports.com',
      him_her: 'her'
    }.freeze,
    'VB' => {
      name: 'Anthony',
      phone: '435-774-4122',
      email: 'anthony@downundersports.com',
      him_her: 'him'
    }.freeze,
    'XC' => {
      name: 'Vern',
      phone: '435-774-4133',
      email: 'vern@downundersports.com',
      him_her: 'him'
    }.freeze,
  }.freeze

end
