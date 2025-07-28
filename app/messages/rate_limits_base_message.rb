require 'messages/base_message'
require 'utils/hash_utils'

module VCAP::CloudController
  class RateLimitsBaseMessage < MetadataBaseMessage
    def self.register_allowed_keys(allowed_keys)
      super(allowed_keys + [:rate_limits])
    end

    def self.rate_limits_requested?
      @rate_limits_requested ||= proc { |a| a.requested?(:rate_limits) }
    end

    class RateLimitsValidator < ActiveModel::Validator
      def validate(record)
        self.record = record

        unless record.rate_limits.is_a? Hash
          record.errors.add(:rate_limits, 'must be an object')
          return
        end

        unless rate_limits.key?(:custom_request_limit)
          record.errors.add(:rate_limits, 'missing key custom_request_limit')
          return
        end

        invalid_keys = record.rate_limits.except(:custom_request_limit).keys
        unexpected_keys = invalid_keys.map { |val| "'" << val.to_s << "'" }.join(' ')
        record.errors.add(:rate_limits, "has unexpected field(s): #{unexpected_keys}") unless invalid_keys.empty?
        custom_request_limit = record.custom_request_limit
        unless custom_request_limit.empty? || custom_request_limit.is_a?(Integer)
          record.errors.add(:rate_limits, "unexpected value #{custom_request_limit} for key custom_request_limit")
        end
      end
    end

    validates_with RateLimitsValidator, if: rate_limits_requested?

    def custom_request_limit
      HashUtils.dig(rate_limits, :custom_request_limit)
    end
  end
end