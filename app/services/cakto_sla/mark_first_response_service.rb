class CaktoSla::MarkFirstResponseService
  pattr_initialize [:conversation!, :at]

  def perform
    conversation.cakto_sla&.mark!(:first_response, at: at || Time.current)
  end
end
