require 'rails_helper'

describe CaktoTickets::CreateService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent, name: 'Ana', email: 'ana@cakto.com.br') }
  let(:team) { create(:team, account: account, name: 'Compliance', allow_auto_assign: false) }
  let(:params) { { team_id: team.id, title: 'Seller bloqueado', description: 'Precisa liberar o saque', priority: 'high', seller: 'Loja X' } }

  def perform(overrides = {})
    described_class.new(account: account, user: user, params: params.merge(overrides)).perform
  end

  it 'opens the ticket as a conversation of the requester in the tickets inbox' do
    conversation = perform

    expect(conversation.inbox.name).to eq('Tickets internos')
    expect(conversation).to have_attributes(team: team, priority: 'high', status: 'open')
    expect(conversation.additional_attributes).to eq('cakto_ticket' => true, 'solicitante_user_id' => user.id)
    expect(conversation.custom_attributes).to eq('cakto_ticket_titulo' => 'Seller bloqueado', 'cakto_ticket_solicitante' => 'Ana',
                                                 'cakto_ticket_seller' => 'Loja X')
    expect(conversation.contact).to have_attributes(name: 'Ana', email: 'ana@cakto.com.br')
    expect(conversation.contact_inbox.source_id).to eq('ana@cakto.com.br')
    expect(conversation.messages.incoming.sole).to have_attributes(sender: conversation.contact,
                                                                   content: "**Seller bloqueado**\n\nPrecisa liberar o saque")
  end

  it 'adds the requester to the tickets inbox and as a participant of the ticket' do
    conversation = perform

    expect(conversation.inbox.members).to eq([user])
    expect(conversation.conversation_participants.pluck(:user_id)).to eq([user.id])
    expect(perform.conversation_participants.pluck(:user_id)).to eq([user.id])
  end

  it 'reuses the requester contact and defaults priority to medium' do
    contact = create(:contact, account: account, email: 'ana@cakto.com.br', name: 'Ana Antiga')

    conversation = perform(priority: nil, seller: nil)

    expect(conversation.contact).to eq(contact)
    expect(conversation.priority).to eq('medium')
    expect(conversation.custom_attributes).not_to have_key('cakto_ticket_seller')
    expect(perform.contact).to eq(contact)
  end

  it 'links the related customer conversation and records activities on both sides' do
    origin = create(:conversation, account: account)

    conversation = nil
    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
      conversation = perform(related_conversation_display_id: origin.display_id)
    end

    expect(conversation.custom_attributes['cakto_ticket_origem']).to eq(origin.display_id.to_s)
    expect(conversation.messages.activity.pluck(:content)).to include("Aberto a partir da conversa ##{origin.display_id}")
    expect(origin.messages.activity.pluck(:content)).to eq(["Ticket interno ##{conversation.display_id} aberto para compliance"])
  end

  it 'rejects missing title or description' do
    expect { perform(title: ' ') }.to raise_error(described_class::Error, 'Informe o título do ticket.')
    expect { perform(description: nil) }.to raise_error(described_class::Error, 'Informe a descrição do ticket.')
  end

  it 'rejects a team of another account, an invalid priority and an unknown related conversation' do
    expect { perform(team_id: create(:team).id) }.to raise_error(described_class::Error, 'Escolha uma equipe válida.')
    expect { perform(priority: 'alta') }.to raise_error(described_class::Error, 'Prioridade inválida.')
    expect { perform(related_conversation_display_id: 9999) }.to raise_error(described_class::Error, 'Conversa #9999 não encontrada.')
    expect(Conversation.count).to eq(0)
  end
end
