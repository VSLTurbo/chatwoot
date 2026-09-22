require 'rails_helper'

RSpec.describe CaktoSlaPolicy do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

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

    it 'normalizes inbox_ids and team_ids' do
      policy = create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id, inbox.id, nil], team_ids: [team.id, nil, team.id])
      expect(policy.reload.inbox_ids).to eq([inbox.id])
      expect(policy.team_ids).to eq([team.id])
    end

    it 'rejects teams from another account' do
      policy = build(:cakto_sla_policy, account: account, team_ids: [team.id, create(:team).id])
      expect(policy).not_to be_valid
      expect(policy.errors[:team_ids]).to be_present
    end

    it 'rejects a team already covered by another active policy' do
      create(:cakto_sla_policy, account: account, team_ids: [team.id])
      policy = build(:cakto_sla_policy, account: account, team_ids: [team.id])
      expect(policy).not_to be_valid
      expect(policy.errors[:team_ids]).to be_present
    end

    it 'allows the same team when the other policy is inactive or is the policy itself' do
      inactive = create(:cakto_sla_policy, account: account, team_ids: [team.id], active: false)
      policy = create(:cakto_sla_policy, account: account, team_ids: [team.id])
      policy.name = 'Outro nome'
      expect(policy).to be_valid
      expect(inactive).to be_valid
    end
  end

  describe '.covering_team' do
    it 'returns the policy whose team_ids include the team' do
      policy = create(:cakto_sla_policy, account: account, team_ids: [team.id])
      create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])
      expect(described_class.covering_team(team.id)).to eq([policy])
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
