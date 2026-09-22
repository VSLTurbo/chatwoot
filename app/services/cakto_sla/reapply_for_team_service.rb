# Transferência de equipe: a conversa passa a seguir a política da equipe nova e os
# prazos ainda pendentes são contados de novo a partir da transferência.
class CaktoSla::ReapplyForTeamService
  KINDS = [:first_response, :resolution].freeze

  pattr_initialize [:conversation!, :at]

  def perform
    return unless conversation.account.feature_enabled?('cakto_sla')
    return if policy.blank?

    sla = conversation.cakto_sla
    return if sla&.cakto_sla_policy_id == policy.id

    if sla
      sla.update!(reapplied_attributes(sla).merge(cakto_sla_policy: policy))
    else
      CaktoSla::ApplyPolicyService.new(conversation: conversation, at: moment).perform
    end
    create_activity
  end

  private

  def moment
    @moment ||= at || Time.current
  end

  def policy
    @policy ||= conversation.team_id && conversation.account.cakto_sla_policies.active.covering_team(conversation.team_id).first
  end

  # Pendente ou não medido: vencimento novo a partir da transferência (ou não medido, se a
  # política nova não mede aquele prazo). Cumprido ou estourado não muda.
  def reapplied_attributes(sla)
    KINDS.each_with_object({}) do |kind, attributes|
      next unless sla.public_send("#{kind}_status_pending?") || sla.public_send("#{kind}_status_not_measured?")

      minutes = policy.public_send("#{kind}_minutes")
      attributes[:"#{kind}_due_at"] = minutes && (moment + minutes.minutes)
      attributes[:"#{kind}_status"] = minutes ? :pending : :not_measured
    end
  end

  def create_activity
    content = "SLA passou a ser da política #{policy.name} (equipe #{conversation.team.name})"
    ::Conversations::ActivityMessageJob.perform_later(
      conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity, content: content }
    )
  end
end
