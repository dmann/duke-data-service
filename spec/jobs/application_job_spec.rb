require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  let(:gateway_exchange_name) { 'test.'+Faker::Internet.slug }
  let(:gateway_exchange) { channel.exchange(gateway_exchange_name) }
  let(:distributor_exchange_name) { 'active_jobs' }
  let(:distributor_exchange_type) { :direct }
  let(:distributor_exchange) { channel.exchange(distributor_exchange_name) }
  let(:message_log_name) { 'message_log' }
  let(:message_log_queue) { channel.queue(message_log_name) }

  let(:bunny_session) { Sneakers::CONFIG[:connection] }
  let(:channel) { bunny_session.channel }

  before do
    Sneakers.configure(exchange: gateway_exchange_name, timeout_job_after: 300, threads: 1)
  end

  it { is_expected.to be_a ActiveJob::Base }
  it { expect{described_class.perform_now}.to raise_error(NotImplementedError) }

  it { expect(described_class).to respond_to(:create_bindings) }
  describe '::create_bindings' do
    let(:create_bindings) { described_class.create_bindings }
    it { expect(bunny_session.exchange_exists?(gateway_exchange_name)).to be_falsey }
    it { expect(bunny_session.exchange_exists?(distributor_exchange_name)).to be_falsey }
    it { expect(bunny_session.queue_exists?(message_log_name)).to be_falsey }
    context 'once called' do
      before { create_bindings }
      it { expect(bunny_session.exchange_exists?(gateway_exchange_name)).to be_truthy }
      it { expect(gateway_exchange.type).to eq(Sneakers::CONFIG[:exchange_options][:type]) }
      it { expect(gateway_exchange).to be_durable }

      it { expect(bunny_session.exchange_exists?(distributor_exchange_name)).to be_truthy }
      it { expect(distributor_exchange.type).to eq(:direct) }
      it { expect(distributor_exchange).to be_durable }

      it { expect(bunny_session.queue_exists?(message_log_name)).to be_truthy }
      it { expect(message_log_queue).to be_durable }

      it { expect(distributor_exchange).to be_bound_to(gateway_exchange) }
      it { expect(message_log_queue).to be_bound_to(gateway_exchange) }
    end
  end

  it { expect(described_class).to respond_to(:job_wrapper) }
  describe '::job_wrapper' do
    it { expect{described_class.job_wrapper}.to raise_error NotImplementedError}
  end

  context 'child_class' do
    let(:prefix) { Rails.application.config.active_job.queue_name_prefix }
    let(:prefix_delimiter) { Rails.application.config.active_job.queue_name_delimiter }
    let(:child_class_queue_name) { Faker::Internet.slug(nil, '_') }
    let(:prefixed_queue_name) { "#{prefix}#{prefix_delimiter}#{child_class_queue_name}"}
    let(:child_class_queue) { channel.queue(prefixed_queue_name) }
    let(:child_class_name) { "#{Faker::Internet.slug(nil, '_')}_job".classify }
    let(:child_class) {
      klass_queue_name = child_class_queue_name
      Object.const_set(child_class_name, Class.new(described_class) do
        queue_as klass_queue_name
        @run_count = 0
        def perform
          self.class.run_count = self.class.run_count.next
        end
        def self.run_count=(val)
          @run_count = val
        end
        def self.run_count
          @run_count
        end
      end)
    }
    it { expect(prefix).not_to be_nil }
    it { expect(prefix_delimiter).not_to be_nil }
    it { expect(child_class.queue_name).to eq(prefixed_queue_name) }

    it { expect{child_class.perform_now}.not_to raise_error }
    it { expect(child_class).to respond_to :run_count }
    describe '::run_count' do
      it { expect(child_class.run_count).to eq 0 }
      context 'after perform_now call' do
        before { child_class.perform_now }
        it { expect(child_class.run_count).to eq 1 }
      end
    end

    context 'without job_wrapper running' do
      it { expect(bunny_session.queue_exists?(prefixed_queue_name)).to be_falsey }
      it { expect{child_class.perform_later}.to raise_error(described_class::QueueNotFound, "Queue #{prefixed_queue_name} does not exist") }
    end

    describe '::job_wrapper' do
      let(:job_wrapper) { child_class.job_wrapper }
      let(:queue_opts) {{
        exchange: distributor_exchange_name,
        exchange_type: distributor_exchange_type
      }}
      it { expect(job_wrapper).to be_a Class }
      it { expect(job_wrapper.ancestors).to include ActiveJob::QueueAdapters::SneakersAdapter::JobWrapper }
      it { expect(job_wrapper.queue_name).to eq child_class.queue_name }
      it { expect(job_wrapper.queue_opts).to eq queue_opts }
      it 'calls ::create_bindings' do
        expect(described_class).to receive(:create_bindings)
        job_wrapper
      end
      it { expect(bunny_session.queue_exists?(child_class_queue_name)).to be_falsey }
      context 'instance created and run' do
        let(:job_wrapper_instance) { child_class.job_wrapper.new }
        before { job_wrapper_instance.run }

        it { expect(bunny_session.queue_exists?(prefixed_queue_name)).to be_truthy }
        it { expect(bunny_session.exchange_exists?(distributor_exchange_name)).to be_truthy }
        it { expect(child_class_queue).to be_bound_to(distributor_exchange) }
        it { expect{child_class.perform_later}.not_to raise_error }
        it { expect{
          child_class.perform_later
          sleep 0.1 while Thread.list.count {|t| t.status == "run"} > 1
        }.to change{child_class.run_count}.by(1) }

        context 'when stopped' do
          before { job_wrapper_instance.stop }
          it { expect{child_class.perform_later}.to change{child_class_queue.message_count}.by(1) }
        end
      end
    end
  end
end
