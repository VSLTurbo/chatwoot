require 'rails_helper'

describe CaktoSla::MarkResolutionService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'marks resolution as met when on time' do
    sla = create(:cakto_conversation_sla, account: account, conversation: conversation, resolution_due_at: 1.hour.from_now)

    described_class.new(conversation: conversation, at: Time.current).perform

    expect(sla.reload).to be_resolution_status_met
    expect(sla.resolution_met_at).to be_present
  end

  it 'marks resolution as breached when late' do
    allow(Conversations::ActivityMessageJob).to receive(:perform_later)
    sla = create(:cakto_conversation_sla, account: account, conversation: conversation, resolution_due_at: 1.hour.ago)

    described_class.new(conversation: conversation, at: Time.current).perform

    expect(sla.reload).to be_resolution_status_breached
  end

  it 'does nothing without an sla' do
    expect { described_class.new(conversation: conversation).perform }.not_to raise_error
  end
end
