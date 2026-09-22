require 'rails_helper'

describe CaktoSla::ReapplyForTeamService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account, name: 'compliance') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team) }
  let(:at) { Time.zone.now }
  let!(:inbox_policy) { create(:cakto_sla_policy, account: account, name: 'Caixa', inbox_ids: [inbox.id]) }
  let!(:team_policy) do
    create(:cakto_sla_policy, account: account, name: 'Área', team_ids: [team.id], first_response_minutes: 30, resolution_minutes: 120)
  end

  before { account.enable_features!('cakto_sla') }

  def create_sla(attributes = {})
    create(:cakto_conversation_sla, { account: account, conversation: conversation, cakto_sla_policy: inbox_policy }.merge(attributes))
  end

  def perform
    described_class.new(conversation: conversation, at: at).perform
  end

  it 'gives pending targets a new due time counted from the transfer' do
    sla = create_sla

    perform

    expect(sla.reload.cakto_sla_policy).to eq(team_policy)
    expect(sla.first_response_due_at.to_i).to eq((at + 30.minutes).to_i)
    expect(sla.resolution_due_at.to_i).to eq((at + 120.minutes).to_i)
    expect(sla).to be_first_response_status_pending
  end

  it 'keeps met and breached targets untouched' do
    met_at = 5.minutes.ago
    sla = create_sla(first_response_status: :met, first_response_met_at: met_at, resolution_status: :breached, breached_at: met_at)
    due = [sla.first_response_due_at, sla.resolution_due_at]

    perform

    expect(sla.reload.cakto_sla_policy).to eq(team_policy)
    expect(sla).to be_first_response_status_met
    expect(sla).to be_resolution_status_breached
    expect([sla.first_response_due_at, sla.resolution_due_at]).to eq(due)
  end

  it 'turns not_measured into pending when the new policy measures that target' do
    sla = create_sla(resolution_status: :not_measured, resolution_due_at: nil)

    perform

    expect(sla.reload).to be_resolution_status_pending
    expect(sla.resolution_due_at.to_i).to eq((at + 120.minutes).to_i)
  end

  it 'turns pending into not_measured when the new policy does not measure that target' do
    team_policy.update!(resolution_minutes: nil)
    sla = create_sla

    perform

    expect(sla.reload).to be_resolution_status_not_measured
    expect(sla.resolution_due_at).to be_nil
  end

  it 'records the activity naming the policy and the team' do
    create_sla

    perform_enqueued_jobs(only: Conversations::ActivityMessageJob) { perform }

    expect(conversation.messages.activity.pluck(:content)).to eq(['SLA passou a ser da política Área (equipe compliance)'])
  end

  it 'creates the sla counting from the transfer when the conversation had none' do
    perform

    sla = conversation.reload.cakto_sla
    expect(sla.cakto_sla_policy).to eq(team_policy)
    expect(sla.first_response_due_at.to_i).to eq((at + 30.minutes).to_i)
  end

  it 'does nothing when the conversation already follows the team policy' do
    sla = create_sla(cakto_sla_policy: team_policy)

    expect { perform }.not_to have_enqueued_job(Conversations::ActivityMessageJob)
    expect { perform }.not_to(change { sla.reload.updated_at })
  end

  it 'does nothing when the new team has no active policy' do
    team_policy.update!(active: false)
    sla = create_sla

    perform

    expect(sla.reload.cakto_sla_policy).to eq(inbox_policy)
    expect(conversation.messages.activity).to be_empty
  end

  it 'does nothing when the feature is disabled' do
    account.disable_features!('cakto_sla')
    sla = create_sla

    perform

    expect(sla.reload.cakto_sla_policy).to eq(inbox_policy)
  end
end
