require 'rails_helper'

RSpec.describe CaktoSla::BreachJob do
  let(:account) { create(:account) }
  let(:policy) { create(:cakto_sla_policy, account: account, name: 'Suporte') }

  def sla_with(first_response_due_at: 1.hour.from_now, resolution_due_at: 1.day.from_now)
    create(:cakto_conversation_sla, account: account, cakto_sla_policy: policy,
                                    first_response_due_at: first_response_due_at, resolution_due_at: resolution_due_at)
  end

  it 'enqueues the job' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue('scheduled_jobs')
  end

  it 'breaches overdue pending targets, labels the conversation and posts an activity' do
    allow(Conversations::ActivityMessageJob).to receive(:perform_later)
    overdue_first = sla_with(first_response_due_at: 5.minutes.ago)
    overdue_resolution = sla_with(resolution_due_at: 5.minutes.ago)
    on_time = sla_with

    described_class.perform_now

    expect(overdue_first.reload).to be_first_response_status_breached
    expect(overdue_first).to be_resolution_status_pending
    expect(overdue_first.conversation.reload.label_list).to include('sla-estourado')
    expect(overdue_resolution.reload).to be_resolution_status_breached
    expect(on_time.reload).to be_first_response_status_pending
    expect(Conversations::ActivityMessageJob).to have_received(:perform_later)
      .with(overdue_first.conversation, hash_including(content: 'SLA de primeira resposta estourado (política Suporte)'))
    expect(Conversations::ActivityMessageJob).to have_received(:perform_later)
      .with(overdue_resolution.conversation, hash_including(content: 'SLA de resolução estourado (política Suporte)'))
  end

  it 'does not touch already met targets' do
    sla = sla_with(first_response_due_at: 5.minutes.ago)
    sla.update!(first_response_status: :met)

    described_class.perform_now

    expect(sla.reload).to be_first_response_status_met
  end

  it 'skips accounts with the feature disabled' do
    account.disable_features!('cakto_sla')
    sla = sla_with(first_response_due_at: 5.minutes.ago)

    described_class.perform_now

    expect(sla.reload).to be_first_response_status_pending
  end
end
