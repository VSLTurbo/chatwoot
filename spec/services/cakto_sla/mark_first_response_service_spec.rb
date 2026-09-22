require 'rails_helper'

describe CaktoSla::MarkFirstResponseService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'marks first response as met when on time' do
    sla = create(:cakto_conversation_sla, account: account, conversation: conversation, first_response_due_at: 15.minutes.from_now)

    described_class.new(conversation: conversation, at: Time.current).perform

    expect(sla.reload).to be_first_response_status_met
  end

  it 'marks first response as breached when late' do
    allow(Conversations::ActivityMessageJob).to receive(:perform_later)
    sla = create(:cakto_conversation_sla, account: account, conversation: conversation, first_response_due_at: 5.minutes.ago)

    described_class.new(conversation: conversation, at: Time.current).perform

    expect(sla.reload).to be_first_response_status_breached
    expect(sla).to be_resolution_status_pending
  end

  it 'does nothing without an sla' do
    expect { described_class.new(conversation: conversation).perform }.not_to raise_error
  end
end
