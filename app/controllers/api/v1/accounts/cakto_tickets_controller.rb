class Api::V1::Accounts::CaktoTicketsController < Api::V1::Accounts::BaseController
  before_action :ensure_cakto_tickets_enabled
  before_action :check_authorization

  rescue_from ::CaktoTickets::CreateService::Error do |exception|
    render json: { message: exception.message }, status: :unprocessable_entity
  end

  def create
    @conversation = ::CaktoTickets::CreateService.new(account: Current.account, user: Current.user, params: permitted_payload).perform
  end

  def setup
    inbox = ::CaktoTickets::SetupService.new(account: Current.account).perform
    teams = Current.account.teams.order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } }
    render json: { inbox_id: inbox.id, teams: teams }
  end

  private

  def ensure_cakto_tickets_enabled
    raise ActiveRecord::RecordNotFound unless Current.account.feature_enabled?('cakto_tickets')
  end

  def check_authorization
    authorize :cakto_ticket, "#{action_name}?"
  end

  def permitted_payload
    params.require(:cakto_ticket).permit(:team_id, :title, :description, :priority, :related_conversation_display_id, :seller)
  end
end
