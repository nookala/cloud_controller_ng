require 'actions/labels_update'
require 'actions/annotations_update'

module VCAP::CloudController
  class RateLimitsUpdate
    class << self
      def update(user, message, destroy_nil: true)
        return unless message.requested?(:rate_limits)

        request_rate_limit = HashUtils.dig(message, :custom_request_limit)
        if request_rate_limit.nil? && destroy_nil # Delete rate limit
            TnzUserAttributeModel.find(user_guid: user.guid)&.destroy
            next
          end

          begin
            tries ||= 2
            TnzUserAttributeModel.db.transaction(savepoint: true) do
              user_attribute = TnzUserAttributeModel.find(user_guid: user.guid)
              if user_attribute.nil?
                TnzUserAttributeModel.create(user_guid: user.guid)
              else
                user_attribute.update(request_rate_limit: request_rate_limit)
              end
            end
          rescue Sequel::UniqueConstraintViolation => e
            if (tries -= 1).positive?
              retry
            else
              v3_api_error!(:UniquenessError, e.message)
            end
          end
        end
      end
    end
  end
end