Sequel.migration do
  change do
    create_table :tnz_user_attributes do
      VCAP::Migration.common(self)
      Integer :request_rate_limit, default: nil
      String :user_guid, size: 255
      foreign_key [:user_guid], :users, key: :guid, name: :fk_tnz_user_attribute_guid
      index [:user_guid], name: :fk_tnz_user_attribute_guid_index
    end
  end
end
