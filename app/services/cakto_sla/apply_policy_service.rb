class CaktoSla::ApplyPolicyService
  # at: instante de início da contagem (padrão: criação da conversa).
  pattr_initialize [:conversation!, :at]

  def perform
    return if conversation.cakto_sla.present?
    return unless conversation.account.feature_enabled?('cakto_sla')

    policy = self.class.policy_for(conversation)
    return if policy.blank?

    conversation.create_cakto_sla!(account_id: conversation.account_id, cakto_sla_policy: policy, **due_attributes(policy))
  end

  # Equipe manda sobre caixa: a política que cobre a equipe da conversa, senão a que cobre a caixa.
  def self.policy_for(conversation)
    policies = conversation.account.cakto_sla_policies.active
    team_policy = conversation.team_id && policies.covering_team(conversation.team_id).first
    team_policy || policies.covering_inbox(conversation.inbox_id).first
  end

  private

  def due_attributes(policy)
    {
      first_response_due_at: due_at(policy.first_response_minutes),
      first_response_status: status_for(policy.first_response_minutes),
      resolution_due_at: due_at(policy.resolution_minutes),
      resolution_status: status_for(policy.resolution_minutes)
    }
  end

  def due_at(minutes)
    minutes && ((at || conversation.created_at) + minutes.minutes)
  end

  def status_for(minutes)
    minutes ? :pending : :not_measured
  end
end
