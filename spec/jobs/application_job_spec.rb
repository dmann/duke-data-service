require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  let(:gateway_exchange_name) { 'test.'+Faker::Internet.slug }
  let(:distributor_exchange_name) { 'active_jobs' }
  let(:message_log_name) { 'message_log' }
  let(:queue_name) { Faker::Internet.slug(nil, '_').to_sym }
  let(:child_class) {
    Class.new(described_class) do
      queue_as queue_name
      def perform
        true
      end
    end
  }
  let(:bunny) { BunnyMock }

  before do
    Sneakers.configure(exchange: gateway_exchange_name)
    Sneakers.logger = Rails.logger # Must reset logger whenever configure is called
  end
  
  it { is_expected.to be_a ActiveJob::Base }
  it { expect{described_class.perform_now}.to raise_error(NotImplementedError) }

  it { expect(described_class).to respond_to(:gateway_exchange) }
  describe '::gateway_exchange' do
    let(:gateway_exchange) { described_class.gateway_exchange }
    it { expect(gateway_exchange).to be_a bunny::Exchange }
    it { expect(gateway_exchange.name).to eq(gateway_exchange_name) }
    it { expect(gateway_exchange.type).to eq(Sneakers::CONFIG[:exchange_options][:type]) }
    it { expect(gateway_exchange).to be_durable }
  end

  it { expect(described_class).to respond_to(:distributor_exchange) }
  describe '::distributor_exchange' do
    let(:distributor_exchange) { described_class.distributor_exchange }
    it { expect(distributor_exchange).to be_a bunny::Exchange }
    it { expect(distributor_exchange.name).to eq(distributor_exchange_name) }
    it { expect(distributor_exchange.type).to eq(:direct) }
    it { expect(distributor_exchange).to be_durable }
  end

  it { expect(described_class).to respond_to(:message_log_queue) }
  describe '::message_log_queue' do
    let(:message_log_queue) { described_class.message_log_queue }
    it { expect(message_log_queue).to be_a bunny::Queue }
    it { expect(message_log_queue.name).to eq(message_log_name) }
    it { expect(message_log_queue).to be_durable }
  end

  it { expect(described_class).to respond_to(:job_wrapper) }
  describe '::job_wrapper' do
    let(:job_wrapper) { described_class.job_wrapper }
    let(:queue_opts) {{
      exchange: described_class.distributor_exchange.name,
      exchange_type: described_class.distributor_exchange.type
    }}
    it { expect(job_wrapper).to be_a Class }
    it { expect(job_wrapper.ancestors).to include ActiveJob::QueueAdapters::SneakersAdapter::JobWrapper }
    it { expect(job_wrapper.queue_name).to eq described_class.queue_name }
    it { expect(job_wrapper.queue_opts).to eq queue_opts }
  end

  context 'child_class' do
    it { expect{child_class.perform_now}.not_to raise_error }
    it { expect{child_class.perform_later}.not_to raise_error }

    describe '::job_wrapper' do
      let(:job_wrapper) { child_class.job_wrapper }
      let(:queue_opts) {{
        exchange: child_class.distributor_exchange.name,
        exchange_type: child_class.distributor_exchange.type
      }}
      it { expect(job_wrapper).to be_a Class }
      it { expect(job_wrapper.ancestors).to include ActiveJob::QueueAdapters::SneakersAdapter::JobWrapper }
      it { expect(job_wrapper.queue_name).to eq child_class.queue_name }
      it { expect(job_wrapper.queue_opts).to eq queue_opts }
    end
  end
end
