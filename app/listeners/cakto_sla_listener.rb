class CaktoSlaListener < BaseListener
  def conversation_created(event)
    conversation = extract_conversation_and_account(event)[0]
    CaktoSla::ApplyPolicyService.new(conversation: conversation).perform
  end

  def first_reply_created(event)
    message = extract_message_and_account(event)[0]
    CaktoSla::MarkFirstResponseService.new(conversation: message.conversation, at: message.created_at).perform
  end

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    CaktoSla::MarkResolutionService.new(conversation: conversation, at: event.timestamp).perform
  end
end
