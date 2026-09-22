require 'rails_helper'

RSpec.describe CaktoSlaPolicy do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:conversation_slas).class_name('CaktoConversationSla') }
  end

  describe 'validations' do
    it 'requires a name' do
      policy = build(:cakto_sla_policy, account: account, name: '')
      expect(policy).not_to be_valid
      expect(policy.errors[:name]).to be_present
    end

    it 'requires minutes to be positive integers when present' do
      expect(build(:cakto_sla_policy, account: account, first_response_minutes: 0)).not_to be_valid
      expect(build(:cakto_sla_policy, account: account, resolution_minutes: -5)).not_to be_valid
      expect(build(:cakto_sla_policy, account: account, resolution_minutes: 1.5)).not_to be_valid
      expect(build(:cakto_sla_policy, account: account, first_response_minutes: nil)).to be_valid
    end

    it 'requires at least one target' do
      policy = build(:cakto_sla_policy, account: account, first_response_minutes: nil, resolution_minutes: nil)
      expect(policy).not_to be_valid
      expect(policy.errors[:base]).to be_present
    end

    it 'rejects inboxes from another account' do
      other_inbox = create(:inbox)
      policy = build(:cakto_sla_policy, account: account, inbox_ids: [inbox.id, other_inbox.id])
      expect(policy).not_to be_valid
      expect(policy.errors[:inbox_ids]).to be_present
    end

    it 'rejects an inbox already covered by another active policy' do
      create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])
      policy = build(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])
      expect(policy).not_to be_valid
      expect(policy.errors[:inbox_ids]).to be_present
    end

    it 'allows the same inbox when the other policy is inactive' do
      create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id], active: false)
      expect(build(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])).to be_valid
    end

    it 'allows updating a policy that already covers the inbox' do
      policy = create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])
      policy.name = 'Outro nome'
      expect(policy).to be_valid
    end

    it 'normalizes inbox_ids' do
      policy = create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id, inbox.id, nil])
      expect(policy.reload.inbox_ids).to eq([inbox.id])
    end
  end

  describe '.covering_inbox' do
    it 'returns the policy whose inbox_ids include the inbox' do
      policy = create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])
      create(:cakto_sla_policy, account: account, inbox_ids: [])
      expect(described_class.covering_inbox(inbox.id)).to eq([policy])
    end
  end
end
