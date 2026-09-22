require 'rails_helper'

describe CaktoSlaListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  before { account.enable_features!('cakto_sla') }

  describe '#conversation_created' do
    it 'applies the policy covering the inbox' do
      create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id])
      event = Events::Base.new('conversation.created', Time.zone.now, conversation: conversation)

      listener.conversation_created(event)

      expect(conversation.reload.cakto_sla).to be_present
    end
  end

  describe '#first_reply_created' do
    it 'marks the first response using the message time' do
      sla = create(:cakto_conversation_sla, account: account, conversation: conversation, first_response_due_at: 15.minutes.from_now)
      message = create(:message, message_type: 'outgoing', account: account, inbox: inbox, conversation: conversation)
      event = Events::Base.new('first.reply.created', Time.zone.now, message: message)

      listener.first_reply_created(event)

      expect(sla.reload).to be_first_response_status_met
      expect(sla.first_response_met_at.to_i).to eq(message.created_at.to_i)
    end
  end

  describe '#conversation_resolved' do
    it 'marks the resolution using the event time' do
      sla = create(:cakto_conversation_sla, account: account, conversation: conversation, resolution_due_at: 1.hour.from_now)
      event = Events::Base.new('conversation.resolved', Time.zone.now, conversation: conversation)

      listener.conversation_resolved(event)

      expect(sla.reload).to be_resolution_status_met
    end
  end

  describe '#team_changed' do
    it 'reapplies the policy of the new team counting from the event time' do
      team = create(:team, account: account)
      policy = create(:cakto_sla_policy, account: account, team_ids: [team.id], first_response_minutes: 30)
      sla = create(:cakto_conversation_sla, account: account, conversation: conversation)
      conversation.update!(team: team)
      timestamp = Time.zone.now
      event = Events::Base.new('team.changed', timestamp, conversation: conversation)

      listener.team_changed(event)

      expect(sla.reload.cakto_sla_policy).to eq(policy)
      expect(sla.first_response_due_at.to_i).to eq((timestamp + 30.minutes).to_i)
    end
  end
end
