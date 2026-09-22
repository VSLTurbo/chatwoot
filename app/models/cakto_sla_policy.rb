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
#  team_ids               :integer          default([]), not null, is an Array
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
  TARGETS = { inbox_ids: 'caixa de entrada', team_ids: 'equipe' }.freeze

  belongs_to :account
  has_many :conversation_slas, class_name: 'CaktoConversationSla', dependent: :delete_all

  scope :active, -> { where(active: true) }
  scope :covering_inbox, ->(inbox_id) { where('? = ANY(inbox_ids)', inbox_id) }
  scope :covering_team, ->(team_id) { where('? = ANY(team_ids)', team_id) }

  before_validation :normalize_target_ids

  validates :name, presence: true
  validates :first_response_minutes, :resolution_minutes,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :at_least_one_target
  validate :inboxes_belong_to_account
  validate :teams_belong_to_account
  validate :targets_not_covered_by_another_active_policy

  private

  def normalize_target_ids
    self.inbox_ids = Array(inbox_ids).compact.uniq
    self.team_ids = Array(team_ids).compact.uniq
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

  def teams_belong_to_account
    return if team_ids.empty? || account.nil?
    return if account.teams.where(id: team_ids).count == team_ids.size

    errors.add(:team_ids, 'contém equipe que não pertence à conta')
  end

  def targets_not_covered_by_another_active_policy
    return unless active?

    others = CaktoSlaPolicy.active.where(account_id: account_id).where.not(id: id)
    TARGETS.each do |column, label|
      ids = public_send(column)
      next if ids.empty?

      errors.add(column, "contém #{label} já coberta por outra política ativa") if others.exists?(["#{column} && ARRAY[?]::integer[]", ids])
    end
  end
end
