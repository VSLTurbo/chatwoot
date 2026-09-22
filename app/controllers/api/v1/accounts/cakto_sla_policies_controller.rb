class Api::V1::Accounts::CaktoSlaPoliciesController < Api::V1::Accounts::BaseController
  before_action :ensure_cakto_sla_enabled
  before_action :fetch_cakto_sla_policy, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @cakto_sla_policies = Current.account.cakto_sla_policies.order(:id)
  end

  def show; end

  def create
    @cakto_sla_policy = Current.account.cakto_sla_policies.create!(permitted_payload)
  end

  def update
    @cakto_sla_policy.update!(permitted_payload)
  end

  def destroy
    @cakto_sla_policy.destroy!
    head :no_content
  end

  private

  def ensure_cakto_sla_enabled
    raise ActiveRecord::RecordNotFound unless Current.account.feature_enabled?('cakto_sla')
  end

  def fetch_cakto_sla_policy
    @cakto_sla_policy = Current.account.cakto_sla_policies.find(params[:id])
  end

  def permitted_payload
    params.require(:cakto_sla_policy).permit(:name, :description, :first_response_minutes, :resolution_minutes, :active, inbox_ids: [], team_ids: [])
  end
end
