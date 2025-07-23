require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::TnzUserAttributeModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      user = User.make(guid: 'dora')
      TnzUserAttributeModel.make(user_guid: user.guid, request_rate_limit: 10000)
      expect(TnzUserAttributeModel.find(user_guid: user.guid).request_rate_limit).to eq 10000
    end
  end
end