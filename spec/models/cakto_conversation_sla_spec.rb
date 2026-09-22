require 'rails_helper'

RSpec.describe CaktoConversationSla do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:policy) { create(:cakto_sla_policy, account: account, name: 'Suporte padrão') }
  let(:sla) do
    create(:cakto_conversation_sla, account: account, conversation: conversation, cakto_sla_policy: policy,
                                    first_response_due_at: 15.minutes.from_now, resolution_due_at: 8.hours.from_now)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:cakto_sla_policy) }
  end

  it 'allows one sla per conversation' do
    sla
    duplicate = build(:cakto_conversation_sla, account: account, conversation: conversation, cakto_sla_policy: policy)
    expect(duplicate).not_to be_valid
  end

  describe '#mark!' do
    it 'marks as met when within the due time' do
      sla.mark!(:first_response, at: 5.minutes.from_now)
      expect(sla.reload).to be_first_response_status_met
      expect(sla.first_response_met_at).to be_present
      expect(sla.breached_at).to be_nil
    end

    it 'marks as breached, labels the conversation and creates an activity when late' do
      allow(Conversations::ActivityMessageJob).to receive(:perform_later)

      sla.mark!(:resolution, at: 9.hours.from_now)

      expect(sla.reload).to be_resolution_status_breached
      expect(sla.breached_at).to be_present
      expect(conversation.reload.label_list).to include('sla-estourado')
      label = account.labels.find_by(title: 'sla-estourado')
      expect(label.color).to eq('#E53935')
      expect(Conversations::ActivityMessageJob).to have_received(:perform_later)
        .with(conversation, { account_id: account.id, inbox_id: conversation.inbox_id, message_type: :activity,
                              content: 'SLA de resolução estourado (política Suporte padrão)' })
    end

    it 'does nothing when the target is not pending' do
      sla.update!(first_response_status: :not_measured)
      sla.mark!(:first_response, at: 1.day.from_now)
      expect(sla.reload).to be_first_response_status_not_measured
    end
  end

  describe '#breach!' do
    it 'reuses the existing label and keeps the first breached_at' do
      create(:label, account: account, title: 'sla-estourado', color: '#000000')
      first_breach = 1.hour.ago
      sla.update!(breached_at: first_breach)
      allow(Conversations::ActivityMessageJob).to receive(:perform_later)

      expect { sla.breach!(:first_response) }.not_to change(account.labels, :count)
      expect(sla.reload.breached_at.to_i).to eq(first_breach.to_i)
      expect(Conversations::ActivityMessageJob).to have_received(:perform_later)
        .with(conversation, hash_including(content: 'SLA de primeira resposta estourado (política Suporte padrão)'))
    end
  end

  describe '#push_event_data' do
    it 'serializes timestamps as unix seconds' do
      data = sla.push_event_data
      expect(data[:policy_id]).to eq(policy.id)
      expect(data[:policy_name]).to eq('Suporte padrão')
      expect(data[:first_response_due_at]).to eq(sla.first_response_due_at.to_i)
      expect(data[:first_response_status]).to eq('pending')
      expect(data[:breached_at]).to be_nil
    end
  end
end
