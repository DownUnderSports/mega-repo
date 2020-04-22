# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/uniform_order'

class User < ApplicationRecord
  class UniformOrder < ApplicationRecord
    # == Constants ============================================================
    UNIFORM_BY_SPORT = {
      BB: {
        provider: :logo_shop,
        shipping_service: 'Priority Mail Regional Rate Box A',
        jersey: {
          color: 'SCARLET/BLACK/WHITE',
          description: 'HIGH FIVE ADULT CAMPUS REVERSIBLE JERSEY',
          number: '332380',
          price: 38_14.cents,
          cost: 40_00.cents,
        }.freeze,
        shorts: {
          color: 'SCARLET/BLACK/WHITE',
          description: 'HIGH FIVE ADULT CAMPUS REVERSIBLE SHORT',
          number: '335850',
          price: 22_24.cents,
          cost: 24_00.cents,
        }
      }.freeze,
      FB: {
        provider: :logo_shop,
        shipping_service: 'Priority Mail Regional Rate Box A',
        jersey: {
          color: 'RED',
          color_2: 'BLUE',
          description: 'NICKELBACK FOOTBALL JERSEY',
          number: 'N4242',
          price: 38_87.cents,
          cost: 40_00.cents,
        }.freeze,
        shorts: {
          color: 'WHITE',
          description: 'A4 FLYLESS GAME PANT',
          number: 'N6181',
          price: 24_64.cents,
          cost: 26_00.cents,
        }
      }.freeze,
      GF: {
        provider: :badger,
        shipping_service: 'Priority Mail Padded Flat Rate Envelope',
        jersey: {
          color: 'TRUE ROYAL/WHITE',
          color_2: 'TRUE RED/WHITE',
          description: 'SPORT TEK DRY ZONE COLORBLOCK RAGLAN POLO',
          number: 'T476',
          price: 20_93.cents,
          cost: 22_50.cents,
        }.freeze,
      }.freeze,
      TF: {
        provider: :badger,
        shipping_service: 'Priority Mail Flat Rate Envelope',
        M: {
          jersey: {
            color: 'RED/WHITE',
            description: "BADGER STRIDE MEN'S SINGLET",
            number: '8667',
            price: 11_58.cents,
            cost: 13_00.cents,
          }.freeze,
          shorts: {
            color: 'ROYAL/WHITE',
            description: "BADGER STRIDE MEN'S SHORT",
            number: '7273',
            price: 14_52.cents,
            cost: 16_00.cents,
          }
        }.freeze,
        W: {
          jersey: {
            color: 'RED/WHITE',
            description: "BADGER STRIDE WOMEN'S SINGLET",
            number: '8967',
            price: 11_58.cents,
            cost: 13_00.cents,
          }.freeze,
          shorts: {
            color: 'ROYAL/WHITE',
            description: "BADGER STRIDE WOMEN'S SHORT",
            number: '7274',
            price: 14_52.cents,
            cost: 16_00.cents,
          }
        }.freeze,
      }.freeze,
      VB: {
        provider: :badger,
        shipping_service: 'Priority Mail Flat Rate Envelope',
        jersey: {
          color: 'SCARLET/WHITE',
          description: 'HIGH FIVE LADIES WAVE JERSEY',
          number: '312032',
          price: 20_25.cents,
          cost: 22_00.cents,
        }.freeze,
        shorts: {
          color: 'ROYAL/WHITE',
          description: 'AUGUSTA LADIES STRIDE SHORT',
          number: '1335',
          price: 16_27.cents,
          cost: 18_00.cents,
        }
      }.freeze,
      XC: {
        provider: :badger,
        shipping_service: 'Priority Mail Flat Rate Envelope',
        M: {
          jersey: {
            color: 'RED/WHITE',
            description: "BADGER STRIDE MEN'S SINGLET",
            number: '8667',
            price: 11_58.cents,
            cost: 13_00.cents,
          }.freeze,
          shorts: {
            color: 'ROYAL/WHITE',
            description: "BADGER STRIDE MEN'S SHORT",
            number: '7273',
            price: 14_52.cents,
            cost: 16_00.cents,
          }
        }.freeze,
        W: {
          jersey: {
            color: 'RED/WHITE',
            description: "BADGER STRIDE WOMEN'S SINGLET",
            number: '8967',
            price: 11_58.cents,
            cost: 13_00.cents,
          }.freeze,
          shorts: {
            color: 'ROYAL/WHITE',
            description: "BADGER STRIDE WOMEN'S SHORT",
            number: '7274',
            price: 14_52.cents,
            cost: 16_00.cents,
          }
        }.freeze,
      }.freeze,
    }.freeze
  end
end
