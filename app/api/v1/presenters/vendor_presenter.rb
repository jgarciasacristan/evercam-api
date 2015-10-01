require_relative './presenter'

module Evercam
  module Presenters
    class Vendor < Presenter

      root :vendors

      expose :id, documentation: {
        type: 'string',
        desc: 'Unique identifier for the vendor',
        required: true
      } do |v,o|
        v.exid
      end

      expose :name, documentation: {
        type: 'string',
        desc: 'Name of the vendor',
        required: true
      }

      expose :known_macs, documentation: {
        type: 'array',
        desc: 'String array of MAC prefixes the vendor uses',
        required: true,
        items: {
          type: 'string'
        }
      }

      expose :total_models, documentation: {
        type: "integer",
        desc: "Total number of models of the vendor",
        required: true
      } do |v, _o|
        v.vendor_models.count
      end

      expose :logo, documentation: {
        type: "string",
        desc: "Vendor logo",
        required: true,
      } do |v, _o|
        "https://evercam-public-assets.s3.amazonaws.com/#{v.exid}/logo.jpg"
      end
    end
  end
end
