require 'rails_helper'

describe CaktoSla::ReportService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp') }
  let(:other_inbox) { create(:inbox, account: account, name: 'Email') }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:policy) { create(:cakto_sla_policy, account: account) }
  # Sem atribuição automática: com ela, a equipe reatribui a conversa a um membro dela e a agente some do relatório.
  let(:team) { create(:team, account: account, name: 'Compliance', allow_auto_assign: false) }

  def sla_for(inbox, first_response:, resolution:, **conversa)
    conversation = create(:conversation, account: account, inbox: inbox, created_at: 1.day.ago, **conversa)
    create(:cakto_conversation_sla, account: account, conversation: conversation, cakto_sla_policy: policy,
                                    first_response_status: first_response, resolution_status: resolution)
  end

  before do
    sla_for(inbox, first_response: :met, resolution: :pending, assignee: agent, team: team)
    sla_for(inbox, first_response: :breached, resolution: :met, assignee: agent)
    sla_for(other_inbox, first_response: :pending, resolution: :not_measured)
    sla_for(inbox, first_response: :met, resolution: :met, created_at: 30.days.ago)
  end

  it 'aggregates totals, by inbox, by agent and by team for conversations created in the period' do
    report = described_class.new(account: account, from: 7.days.ago, to: Time.current).perform

    expect(report[:totals]).to eq(
      conversations: 3,
      first_response: { measured: 3, met: 1, breached: 1, pending: 1 },
      resolution: { measured: 2, met: 1, breached: 0, pending: 1 }
    )
    expect(report[:by_inbox].map { |row| row[:inbox_name] }).to eq(%w[WhatsApp Email])
    expect(report[:by_inbox].first[:conversations]).to eq(2)
    expect(report[:by_agent]).to eq([{ assignee_id: agent.id, name: 'Ana', conversations: 2,
                                       first_response: { measured: 2, met: 1, breached: 1, pending: 0 },
                                       resolution: { measured: 2, met: 1, breached: 0, pending: 1 } }])
    expect(report[:by_team]).to eq([{ team_id: team.id, team_name: 'compliance', conversations: 1,
                                      first_response: { measured: 1, met: 1, breached: 0, pending: 0 },
                                      resolution: { measured: 1, met: 0, breached: 0, pending: 1 } }])
  end

  it 'filters by inbox' do
    report = described_class.new(account: account, from: 7.days.ago, to: Time.current, inbox_id: other_inbox.id).perform

    expect(report[:totals][:conversations]).to eq(1)
    expect(report[:by_inbox].size).to eq(1)
    expect(report[:by_agent]).to eq([])
    expect(report[:by_team]).to eq([])
  end
end
