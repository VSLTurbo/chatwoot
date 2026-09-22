class CaktoSla::BreachJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    now = Time.current
    breach(CaktoConversationSla.first_response_status_pending.where(first_response_due_at: ..now), :first_response)
    breach(CaktoConversationSla.resolution_status_pending.where(resolution_due_at: ..now), :resolution)
  end

  private

  def breach(scope, kind)
    scope.includes(:account, :conversation, :cakto_sla_policy).find_each(batch_size: 100) do |sla|
      next unless sla.account.feature_enabled?('cakto_sla')

      sla.breach!(kind)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: sla.account).capture_exception
    end
  end
end
