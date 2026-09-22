# == Schema Information
#
# Table name: cakto_sla_policies
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  description            :text
#  first_response_minutes :integer
#  inbox_ids              :integer          default([]), not null, is an Array
#  name                   :string           not null
#  resolution_minutes     :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#
# Indexes
#
#  index_cakto_sla_policies_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#
class CaktoSlaPolicy < ApplicationRecord
  belongs_to :account
  has_many :conversation_slas, class_name: 'CaktoConversationSla', dependent: :delete_all

  scope :active, -> { where(active: true) }
  scope :covering_inbox, ->(inbox_id) { where('? = ANY(inbox_ids)', inbox_id) }

  before_validation :normalize_inbox_ids

  validates :name, presence: true
  validates :first_response_minutes, :resolution_minutes,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :at_least_one_target
  validate :inboxes_belong_to_account
  validate :inboxes_not_covered_by_another_active_policy

  private

  def normalize_inbox_ids
    self.inbox_ids = Array(inbox_ids).compact.uniq
  end

  def at_least_one_target
    return if first_response_minutes.present? || resolution_minutes.present?

    errors.add(:base, 'Informe ao menos um prazo: primeira resposta ou resolução')
  end

  def inboxes_belong_to_account
    return if inbox_ids.empty? || account.nil?
    return if account.inboxes.where(id: inbox_ids).count == inbox_ids.size

    errors.add(:inbox_ids, 'contém caixa de entrada que não pertence à conta')
  end

  def inboxes_not_covered_by_another_active_policy
    return unless active? && inbox_ids.any?

    conflict = CaktoSlaPolicy.active.where(account_id: account_id).where.not(id: id)
                             .exists?(['inbox_ids && ARRAY[?]::integer[]', inbox_ids])
    errors.add(:inbox_ids, 'contém caixa de entrada já coberta por outra política ativa') if conflict
  end
end
