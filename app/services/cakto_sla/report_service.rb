class CaktoSla::ReportService
  pattr_initialize [:account!, :from!, :to!, :inbox_id]

  # ponytail: agrega em Ruby sobre um pluck único; trocar por GROUP BY se o período passar de ~100k conversas
  def perform
    rows = scope.pluck('conversations.inbox_id', 'conversations.assignee_id', :first_response_status, :resolution_status)

    {
      totals: summarize(rows),
      by_inbox: grouped(rows, 0, account.inboxes) { |inbox| { inbox_id: inbox.id, inbox_name: inbox.name } },
      by_agent: grouped(rows, 1, account.users) { |user| { assignee_id: user.id, name: user.name } }
    }
  end

  private

  def scope
    result = CaktoConversationSla.joins(:conversation)
                                 .where(account_id: account.id, conversations: { created_at: from..to })
    result = result.where(conversations: { inbox_id: inbox_id }) if inbox_id.present?
    result
  end

  def grouped(rows, index, records)
    groups = rows.group_by { |row| row[index] }
    items = records.where(id: groups.keys.compact).map { |record| yield(record).merge(summarize(groups[record.id])) }
    items.sort_by { |item| -item[:conversations] }
  end

  def summarize(rows)
    {
      conversations: rows.size,
      first_response: bucket(rows.map { |row| row[2] }),
      resolution: bucket(rows.map { |row| row[3] })
    }
  end

  def bucket(statuses)
    tally = statuses.tally
    {
      measured: statuses.size - tally.fetch('not_measured', 0),
      met: tally.fetch('met', 0),
      breached: tally.fetch('breached', 0),
      pending: tally.fetch('pending', 0)
    }
  end
end
