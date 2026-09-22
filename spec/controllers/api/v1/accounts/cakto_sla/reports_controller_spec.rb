require 'rails_helper'

RSpec.describe 'Cakto SLA Report API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/cakto_sla/report' do
    before do
      conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
      create(:cakto_conversation_sla, account: account, conversation: conversation, first_response_status: :met)
    end

    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/cakto_sla/report"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'is forbidden for an agent' do
      get "/api/v1/accounts/#{account.id}/cakto_sla/report", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the report for an administrator' do
      get "/api/v1/accounts/#{account.id}/cakto_sla/report",
          params: { since: 1.day.ago.to_i, until: Time.current.to_i, inbox_id: inbox.id },
          headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['totals']['conversations']).to eq(1)
      expect(body['totals']['first_response']).to eq('measured' => 1, 'met' => 1, 'breached' => 0, 'pending' => 0)
      expect(body['by_inbox'].first['inbox_id']).to eq(inbox.id)
      expect(body['by_agent'].first['assignee_id']).to eq(agent.id)
    end

    it 'defaults to the last seven days' do
      get "/api/v1/accounts/#{account.id}/cakto_sla/report", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['totals']['conversations']).to eq(1)
    end

    it 'returns not found when the feature is disabled' do
      account.disable_features!('cakto_sla')

      get "/api/v1/accounts/#{account.id}/cakto_sla/report", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
