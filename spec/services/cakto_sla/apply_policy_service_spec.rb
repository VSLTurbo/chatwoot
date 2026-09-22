require 'rails_helper'

describe CaktoSla::ApplyPolicyService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  it 'creates the conversation sla from the active policy covering the inbox' do
    policy = create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id], first_response_minutes: 15, resolution_minutes: 480)

    described_class.new(conversation: conversation).perform

    sla = conversation.reload.cakto_sla
    expect(sla.cakto_sla_policy).to eq(policy)
    expect(sla.first_response_due_at.to_i).to eq((conversation.created_at + 15.minutes).to_i)
    expect(sla.resolution_due_at.to_i).to eq((conversation.created_at + 480.minutes).to_i)
    expect(sla).to be_first_response_status_pending
    expect(sla).to be_resolution_status_pending
  end

  it 'marks a nil target as not_measured' do
    create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id], first_response_minutes: 15, resolution_minutes: nil)

    described_class.new(conversation: conversation).perform

    sla = conversation.reload.cakto_sla
    expect(sla.resolution_due_at).to be_nil
    expect(sla).to be_resolution_status_not_measured
  end

  it 'does nothing when no active policy covers the inbox' do
    create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id], active: false)

    described_class.new(conversation: conversation).perform

    expect(conversation.reload.cakto_sla).to be_nil
  end

  it 'does nothing when the feature is disabled' do
    account.disable_features!('cakto_sla')
    create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])

    described_class.new(conversation: conversation).perform

    expect(conversation.reload.cakto_sla).to be_nil
  end

  it 'does not replace an existing sla' do
    existing = create(:cakto_conversation_sla, account: account, conversation: conversation)
    create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])

    described_class.new(conversation: conversation).perform

    expect(conversation.reload.cakto_sla).to eq(existing)
  end
end
