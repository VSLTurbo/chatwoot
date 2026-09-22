require 'rails_helper'

RSpec.describe 'Cakto SLA Policies API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  before { account.enable_features!('cakto_sla') }

  describe 'GET /api/v1/accounts/{account.id}/cakto_sla_policies' do
    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/cakto_sla_policies"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the policies of the account for an agent' do
      policy = create(:cakto_sla_policy, account: account, inbox_ids: [inbox.id], team_ids: [team.id])
      create(:cakto_sla_policy)

      get "/api/v1/accounts/#{account.id}/cakto_sla_policies", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.size).to eq(1)
      expect(body.first).to include('id' => policy.id, 'name' => policy.name, 'inbox_ids' => [inbox.id], 'team_ids' => [team.id],
                                    'active' => true, 'first_response_minutes' => 15, 'resolution_minutes' => 480)
      expect(body.first['created_at']).to eq(policy.created_at.to_i)
    end

    it 'returns not found when the feature is disabled' do
      account.disable_features!('cakto_sla')

      get "/api/v1/accounts/#{account.id}/cakto_sla_policies", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/cakto_sla_policies/:id' do
    let(:policy) { create(:cakto_sla_policy, account: account) }

    it 'shows the policy' do
      get "/api/v1/accounts/#{account.id}/cakto_sla_policies/#{policy.id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).to eq(policy.id)
    end

    it 'returns not found for a policy of another account' do
      other = create(:cakto_sla_policy)

      get "/api/v1/accounts/#{account.id}/cakto_sla_policies/#{other.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/cakto_sla_policies' do
    let(:payload) do
      { cakto_sla_policy: { name: 'Suporte padrão', description: 'Fila principal', first_response_minutes: 15,
                            resolution_minutes: 480, inbox_ids: [inbox.id], team_ids: [team.id], active: true } }
    end

    it 'creates the policy for an administrator' do
      expect do
        post "/api/v1/accounts/#{account.id}/cakto_sla_policies", params: payload, headers: admin.create_new_auth_token, as: :json
      end.to change(CaktoSlaPolicy, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'Suporte padrão', 'inbox_ids' => [inbox.id], 'team_ids' => [team.id])
    end

    it 'is forbidden for an agent' do
      expect do
        post "/api/v1/accounts/#{account.id}/cakto_sla_policies", params: payload, headers: agent.create_new_auth_token, as: :json
      end.not_to change(CaktoSlaPolicy, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects an invalid policy' do
      payload[:cakto_sla_policy].merge!(first_response_minutes: nil, resolution_minutes: nil)

      post "/api/v1/accounts/#{account.id}/cakto_sla_policies", params: payload, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/cakto_sla_policies/:id' do
    let(:policy) { create(:cakto_sla_policy, account: account) }

    it 'updates the policy for an administrator' do
      patch "/api/v1/accounts/#{account.id}/cakto_sla_policies/#{policy.id}",
            params: { cakto_sla_policy: { name: 'Novo nome', active: false } },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(policy.reload.name).to eq('Novo nome')
      expect(policy.active).to be(false)
    end

    it 'is forbidden for an agent' do
      patch "/api/v1/accounts/#{account.id}/cakto_sla_policies/#{policy.id}",
            params: { cakto_sla_policy: { name: 'Novo nome' } },
            headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/cakto_sla_policies/:id' do
    let!(:policy) { create(:cakto_sla_policy, account: account) }

    it 'deletes the policy for an administrator' do
      expect do
        delete "/api/v1/accounts/#{account.id}/cakto_sla_policies/#{policy.id}", headers: admin.create_new_auth_token, as: :json
      end.to change(CaktoSlaPolicy, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'is forbidden for an agent' do
      delete "/api/v1/accounts/#{account.id}/cakto_sla_policies/#{policy.id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
