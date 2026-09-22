class CaktoSla::MarkResolutionService
  pattr_initialize [:conversation!, :at]

  def perform
    conversation.cakto_sla&.mark!(:resolution, at: at || Time.current)
  end
end
