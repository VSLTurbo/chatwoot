class CaktoSla::ApplyPolicyService
  pattr_initialize [:conversation!]

  def perform
    return if conversation.cakto_sla.present?
    return unless conversation.account.feature_enabled?('cakto_sla')

    policy = conversation.account.cakto_sla_policies.active.covering_inbox(conversation.inbox_id).first
    return if policy.blank?

    conversation.create_cakto_sla!(account_id: conversation.account_id, cakto_sla_policy: policy, **due_attributes(policy))
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
    minutes && (conversation.created_at + minutes.minutes)
  end

  def status_for(minutes)
    minutes ? :pending : :not_measured
  end
end
