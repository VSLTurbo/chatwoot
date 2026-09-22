# Garante a caixa "Tickets internos" (Channel::Api, sem webhook) e os atributos de
# conversa que o painel lateral mostra. Idempotente: pode rodar a cada ticket.
class CaktoTickets::SetupService
  INBOX_NAME = 'Tickets internos'.freeze
  ATTRIBUTES = {
    'cakto_ticket_titulo' => 'Título do ticket',
    'cakto_ticket_solicitante' => 'Solicitante',
    'cakto_ticket_seller' => 'Seller',
    'cakto_ticket_origem' => 'Conversa de origem'
  }.freeze

  pattr_initialize [:account!]

  def perform
    ensure_attribute_definitions
    inbox
  end

  def inbox
    @inbox ||= find_inbox || create_inbox
  end

  private

  def find_inbox
    account.inboxes.find_by(name: INBOX_NAME, channel_type: 'Channel::Api')
  end

  def create_inbox
    account.inboxes.create!(name: INBOX_NAME, channel: Channel::Api.create!(account: account))
  end

  def ensure_attribute_definitions
    ATTRIBUTES.each do |key, display_name|
      account.custom_attribute_definitions.find_or_create_by!(attribute_key: key, attribute_model: :conversation_attribute) do |definition|
        definition.attribute_display_name = display_name
        definition.attribute_display_type = :text
      end
    end
  end
end
