# == Schema Information
#
# Table name: cakto_conversation_slas
#
#  id                     :bigint           not null, primary key
#  breached_at            :datetime
#  first_response_due_at  :datetime
#  first_response_met_at  :datetime
#  first_response_status  :integer          default("pending"), not null
#  resolution_due_at      :datetime
#  resolution_met_at      :datetime
#  resolution_status      :integer          default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  cakto_sla_policy_id    :bigint           not null
#  conversation_id        :bigint           not null
#
# Indexes
#
#  index_cakto_conversation_slas_on_account_id                            (account_id)
#  idx_cakto_conv_slas_acct_fr_status                                     (account_id,first_response_status)
#  idx_cakto_conv_slas_acct_res_status                                    (account_id,resolution_status)
#  index_cakto_conversation_slas_on_cakto_sla_policy_id                   (cakto_sla_policy_id)
#  index_cakto_conversation_slas_on_conversation_id                       (conversation_id) UNIQUE
#  index_cakto_conversation_slas_on_first_response_due_at                 (first_response_due_at)
#  index_cakto_conversation_slas_on_resolution_due_at                     (resolution_due_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (cakto_sla_policy_id => cakto_sla_policies.id) ON DELETE => cascade
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#
class CaktoConversationSla < ApplicationRecord
  STATUSES = { pending: 0, met: 1, breached: 2, not_measured: 3 }.freeze
  BREACH_LABEL = 'sla-estourado'.freeze
  BREACH_MESSAGES = {
    first_response: 'SLA de primeira resposta estourado (política %<policy>s)',
    resolution: 'SLA de resolução estourado (política %<policy>s)'
  }.freeze

  belongs_to :account
  belongs_to :conversation, inverse_of: :cakto_sla
  belongs_to :cakto_sla_policy

  enum first_response_status: STATUSES, _prefix: true
  enum resolution_status: STATUSES, _prefix: true

  validates :conversation_id, uniqueness: true

  # kind: :first_response ou :resolution. Só age se o prazo ainda estiver pendente.
  def mark!(kind, at: Time.current)
    return unless public_send("#{kind}_status_pending?")

    at <= public_send("#{kind}_due_at") ? meet!(kind, at) : breach!(kind, at)
  end

  def breach!(kind, at = Time.current)
    update!("#{kind}_status" => :breached, 'breached_at' => breached_at || at)
    add_breach_label
    create_breach_activity(kind)
  end

  def push_event_data
    {
      policy_id: cakto_sla_policy_id,
      policy_name: cakto_sla_policy.name,
      first_response_due_at: first_response_due_at&.to_i,
      resolution_due_at: resolution_due_at&.to_i,
      first_response_status: first_response_status,
      resolution_status: resolution_status,
      breached_at: breached_at&.to_i
    }
  end

  private

  def meet!(kind, at)
    update!("#{kind}_status" => :met, "#{kind}_met_at" => at)
  end

  def add_breach_label
    return if conversation.label_list.include?(BREACH_LABEL)

    account.labels.find_or_create_by!(title: BREACH_LABEL) do |label|
      label.description = 'SLA estourado'
      label.color = '#E53935'
    end
    conversation.add_labels(BREACH_LABEL)
  end

  def create_breach_activity(kind)
    content = format(BREACH_MESSAGES.fetch(kind), policy: cakto_sla_policy.name)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      { account_id: account_id, inbox_id: conversation.inbox_id, message_type: :activity, content: content }
    )
  end
end
