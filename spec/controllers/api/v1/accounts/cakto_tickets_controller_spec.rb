require 'rails_helper'

RSpec.describe 'Cakto Tickets API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Ana', email: 'ana@cakto.com.br') }
  let(:team) { create(:team, account: account, name: 'Compliance', allow_auto_assign: false) }

  before { account.enable_features!('cakto_tickets') }

  describe 'GET /api/v1/accounts/{account.id}/cakto_tickets/setup' do
    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/cakto_tickets/setup"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates the tickets inbox and lists the teams for an agent' do
      team

      get "/api/v1/accounts/#{account.id}/cakto_tickets/setup", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      inbox = account.inboxes.find_by(name: 'Tickets internos')
      expect(response.parsed_body).to eq('inbox_id' => inbox.id, 'teams' => [{ 'id' => team.id, 'name' => 'compliance' }])
    end

    it 'returns not found when the feature is disabled' do
      account.disable_features!('cakto_tickets')

      get "/api/v1/accounts/#{account.id}/cakto_tickets/setup", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/cakto_tickets' do
    let(:payload) do
      { cakto_ticket: { team_id: team.id, title: 'Seller bloqueado', description: 'Precisa liberar o saque', priority: 'urgent' } }
    end

    it 'returns unauthorized for an unauthenticated user' do
      post "/api/v1/accounts/#{account.id}/cakto_tickets", params: payload, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates the ticket and renders the conversation' do
      expect do
        post "/api/v1/accounts/#{account.id}/cakto_tickets", params: payload, headers: agent.create_new_auth_token, as: :json
      end.to change(Conversation, :count).by(1)

      expect(response).to have_http_status(:success)
      conversation = Conversation.last
      body = response.parsed_body
      expect(body['id']).to eq(conversation.display_id)
      expect(body).to include('priority' => 'urgent',
                              'additional_attributes' => { 'cakto_ticket' => true, 'solicitante_user_id' => agent.id })
      expect(body['custom_attributes']['cakto_ticket_titulo']).to eq('Seller bloqueado')
      expect(body['meta']['team']['id']).to eq(team.id)
      expect(body['meta']['sender']['email']).to eq('ana@cakto.com.br')
    end

    it 'returns a portuguese message on validation errors' do
      payload[:cakto_ticket][:title] = ''

      post "/api/v1/accounts/#{account.id}/cakto_tickets", params: payload, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq('message' => 'Informe o título do ticket.')
    end

    it 'rejects an unknown related conversation' do
      payload[:cakto_ticket][:related_conversation_display_id] = 4242

      post "/api/v1/accounts/#{account.id}/cakto_tickets", params: payload, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('Conversa #4242 não encontrada.')
    end

    it 'returns not found when the feature is disabled' do
      account.disable_features!('cakto_tickets')

      post "/api/v1/accounts/#{account.id}/cakto_tickets", params: payload, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
