module VCAP::CloudController
  class TnzUserAttributeModel < Sequel::Model(:tnz_user_attributes)
     set_primary_key :id
     many_to_one :user,
                class: 'VCAP::CloudController::UserModel',
                primary_key: :guid,
                key: :user_guid,
                without_guid_generation: true
  end
end