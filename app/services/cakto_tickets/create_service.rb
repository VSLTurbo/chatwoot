# Abre um ticket interno: o atendente logado vira o contato da conversa na caixa
# "Tickets internos", a conversa nasce para uma equipe e a descrição entra como
# primeira mensagem incoming, para a área responder pelo próprio ticket.
class CaktoTickets::CreateService
  class Error < StandardError; end

  PRIORITIES = %w[low medium high urgent].freeze

  pattr_initialize [:account!, :user!, :params!]

  def perform
    validate!
    ActiveRecord::Base.transaction do
      @conversation = create_conversation
      create_first_message
      add_requester_as_participant
    end
    create_activities
    @conversation
  end

  private

  def validate!
    raise Error, 'Informe o título do ticket.' if title.blank?
    raise Error, 'Informe a descrição do ticket.' if description.blank?
    raise Error, 'Escolha uma equipe válida.' if team.blank?
    raise Error, 'Prioridade inválida.' unless PRIORITIES.include?(priority)
    raise Error, "Conversa ##{params[:related_conversation_display_id]} não encontrada." if related_requested? && related_conversation.blank?
  end

  def title
    params[:title].to_s.strip
  end

  def description
    params[:description].to_s.strip
  end

  def priority
    params[:priority].presence || 'medium'
  end

  def team
    @team ||= account.teams.find_by(id: params[:team_id])
  end

  def related_requested?
    params[:related_conversation_display_id].present?
  end

  def related_conversation
    return unless related_requested?

    @related_conversation ||= account.conversations.find_by(display_id: params[:related_conversation_display_id])
  end

  def inbox
    @inbox ||= CaktoTickets::SetupService.new(account: account).perform
  end

  # Contato do solicitante: reaproveita o contato com o e-mail dele e o vínculo com a caixa (source_id = e-mail).
  def contact_inbox
    @contact_inbox ||= ContactInboxWithContactBuilder.new(
      inbox: inbox, contact_attributes: { name: user.name, email: user.email }, source_id: user.email
    ).perform
  end

  def create_conversation
    account.conversations.create!(
      inbox: inbox, contact: contact_inbox.contact, contact_inbox: contact_inbox,
      team: team, priority: priority, status: :open,
      additional_attributes: { 'cakto_ticket' => true, 'solicitante_user_id' => user.id },
      custom_attributes: custom_attributes
    )
  end

  def custom_attributes
    {
      'cakto_ticket_titulo' => title,
      'cakto_ticket_solicitante' => user.name,
      'cakto_ticket_seller' => params[:seller].to_s.strip.presence,
      'cakto_ticket_origem' => related_conversation&.display_id&.to_s
    }.compact
  end

  def create_first_message
    @conversation.messages.create!(
      account_id: account.id, inbox_id: inbox.id, message_type: :incoming,
      sender: contact_inbox.contact, content: "**#{title}**\n\n#{description}"
    )
  end

  # O solicitante entra na caixa de tickets (para ver o ticket e poder ser mencionado) e vira
  # participante, o que liga as notificações nativas a cada resposta.
  def add_requester_as_participant
    inbox.inbox_members.find_or_create_by!(user: user)
    @conversation.conversation_participants.create!(user: user)
  end

  # Fora da transação: o display_id vem de trigger do banco e só é carregado após o commit.
  def create_activities
    return if related_conversation.blank?

    activity(@conversation, "Aberto a partir da conversa ##{related_conversation.display_id}")
    activity(related_conversation, "Ticket interno ##{@conversation.display_id} aberto para #{team.name}")
  end

  def activity(conversation, content)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation, { account_id: account.id, inbox_id: conversation.inbox_id, message_type: :activity, content: content }
    )
  end
end
