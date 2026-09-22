require 'rails_helper'

describe CaktoTicketsListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:requester) { create(:user, account: account, role: :agent, name: 'Ana Souza') }
  let(:team) { create(:team, account: account, name: 'compliance') }
  let!(:conversation) do
    create(:conversation, account: account, inbox: inbox, team: team, status: :resolved,
                          additional_attributes: { 'cakto_ticket' => true, 'solicitante_user_id' => requester.id })
  end
  let(:event) { Events::Base.new('conversation.resolved', Time.zone.now, conversation: conversation) }

  before { create(:inbox_member, user: requester, inbox: inbox) }

  describe '#conversation_resolved' do
    it 'leaves a private note mentioning the requester, which notifies them' do
      perform_enqueued_jobs(only: EventDispatcherJob) { listener.conversation_resolved(event) }

      note = conversation.messages.where(private: true).sole
      expect(note.content).to eq("[@Ana Souza](mention://user/#{requester.id}/Ana%20Souza) " \
                                 "Seu ticket ##{conversation.display_id} foi resolvido pela equipe compliance.")
      expect(note).to be_outgoing
      expect(requester.notifications.pluck(:notification_type)).to eq(['conversation_mention'])
      expect(requester.notifications.sole.primary_actor).to eq(conversation)
    end

    it 'ignores conversations that are not internal tickets' do
      conversation.update!(additional_attributes: {})

      listener.conversation_resolved(event)

      expect(conversation.messages.where(private: true)).to be_empty
    end

    it 'ignores tickets whose requester no longer exists' do
      conversation.update!(additional_attributes: { 'cakto_ticket' => true, 'solicitante_user_id' => 0 })

      listener.conversation_resolved(event)

      expect(conversation.messages.where(private: true)).to be_empty
    end
  end
end
