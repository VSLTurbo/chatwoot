# Avisa o solicitante do ticket interno quando a área resolve: nota privada com menção,
# que segue o caminho nativo (message.created -> Messages::MentionService -> notificação).
class CaktoTicketsListener < BaseListener
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    return unless conversation.additional_attributes['cakto_ticket']

    requester = User.find_by(id: conversation.additional_attributes['solicitante_user_id'])
    return if requester.blank?

    conversation.messages.create!(
      account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing, private: true,
      sender: Current.user, content: note_content(conversation, requester)
    )
  end

  private

  def note_content(conversation, requester)
    mention = "[@#{requester.name}](mention://user/#{requester.id}/#{ERB::Util.url_encode(requester.name)})"
    team = conversation.team ? " pela equipe #{conversation.team.name}" : ''
    "#{mention} Seu ticket ##{conversation.display_id} foi resolvido#{team}."
  end
end
