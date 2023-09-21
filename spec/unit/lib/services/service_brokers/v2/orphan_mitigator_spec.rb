require 'spec_helper'

module VCAP::Services
  module ServiceBrokers::V2
    RSpec.describe OrphanMitigator do
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }
      let(:service_binding) { VCAP::CloudController::ServiceBinding.make }
      let(:service_key) { VCAP::CloudController::ServiceKey.make }
      let(:name) { 'fake-name' }

      describe 'cleanup_failed_provision' do
        it 'enqueues a deprovison job' do
          mock_enqueuer = double(:enqueuer, enqueue: nil)
          allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(mock_enqueuer)

          OrphanMitigator.new.cleanup_failed_provision(service_instance)

          expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new) do |job, opts|
            expect(opts[:queue]).to eq VCAP::CloudController::Jobs::Queues.generic

            expect(job).to be_a VCAP::CloudController::Jobs::Services::DeleteOrphanedInstance
            expect(job.name).to eq 'service-instance-deprovision'
            expect(job.service_instance_guid).to eq service_instance.guid
            expect(job.service_plan_guid).to eq service_instance.service_plan.guid
          end

          expect(mock_enqueuer).to have_received(:enqueue)
        end

        specify 'the enqueued job has a reschedule_at define such that exponential backoff occurs' do
          now = Time.now.utc

          OrphanMitigator.new.cleanup_failed_provision(service_instance)
          job = Delayed::Job.first.payload_object
          expect(job).to respond_to :reschedule_at

          10.times do |attempt|
            expect(job.reschedule_at(now, attempt)).to be_within(0.01).of(now + (2**attempt).minutes)
          end
        end
      end

      describe 'cleanup_failed_bind' do
        RSpec.shared_examples 'enqueues a job with the right data' do
          let(:mock_enqueuer) { double(:enqueuer, enqueue: nil) }

          before do
            allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(mock_enqueuer)
            OrphanMitigator.new.cleanup_failed_bind(binding)
          end

          it 'enqueues an unbind job' do
            expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new) do |job, opts|
              expect(opts[:queue]).to eq VCAP::CloudController::Jobs::Queues.generic

              expect(job).to be_a VCAP::CloudController::Jobs::Services::DeleteOrphanedBinding
              expect(job.name).to eq 'service-instance-unbind'
              expect(job.binding_info.guid).to eq binding.guid
              expect(job.binding_info.service_instance_guid).to eq binding.service_instance.guid
            end

            expect(mock_enqueuer).to have_received(:enqueue)
          end
        end

        context 'when service app binding' do
          let(:binding) { service_binding }
          it_behaves_like 'enqueues a job with the right data'
        end

        context 'when service key' do
          let(:binding) { service_key }
          it_behaves_like 'enqueues a job with the right data'
        end

        specify 'the enqueued job has a reschedule_at define such that exponential backoff occurs' do
          now = Time.now.utc

          OrphanMitigator.new.cleanup_failed_bind(service_binding)
          job = Delayed::Job.first.payload_object
          expect(job).to respond_to :reschedule_at

          10.times do |attempt|
            expect(job.reschedule_at(now, attempt)).to be_within(0.01).of(now + (2**attempt).minutes)
          end
        end
      end

      describe 'cleanup_failed_key' do
        it 'enqueues an service_key_delete job' do
          mock_enqueuer = double(:enqueuer, enqueue: nil)
          allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(mock_enqueuer)

          OrphanMitigator.new.cleanup_failed_key(service_key)

          expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new) do |job, opts|
            expect(opts[:queue]).to eq VCAP::CloudController::Jobs::Queues.generic

            expect(job).to be_a VCAP::CloudController::Jobs::Services::DeleteOrphanedKey
            expect(job.name).to eq 'service-key-delete'
            expect(job.key_guid).to eq service_key.guid
            expect(job.service_instance_guid).to eq service_key.service_instance.guid
          end

          expect(mock_enqueuer).to have_received(:enqueue)
        end

        specify 'the enqueued job has a reschedule_at define such that exponential backoff occurs' do
          now = Time.now.utc

          OrphanMitigator.new.cleanup_failed_key(service_key)
          job = Delayed::Job.first.payload_object
          expect(job).to respond_to :reschedule_at

          10.times do |attempt|
            expect(job.reschedule_at(now, attempt)).to be_within(0.01).of(now + (2**attempt).minutes)
          end
        end
      end
    end
  end
end
