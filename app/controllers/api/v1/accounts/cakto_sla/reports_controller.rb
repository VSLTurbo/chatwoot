class Api::V1::Accounts::CaktoSla::ReportsController < Api::V1::Accounts::BaseController
  before_action :ensure_cakto_sla_enabled
  before_action :check_authorization

  def show
    render json: ::CaktoSla::ReportService.new(
      account: Current.account, from: from_param, to: to_param, inbox_id: params[:inbox_id]
    ).perform
  end

  private

  def from_param
    params[:since].present? ? Time.zone.at(params[:since].to_i) : 7.days.ago
  end

  # `until` chega em segundos inteiros; +1 s inclui a conversa criada no mesmo segundo.
  def to_param
    params[:until].present? ? Time.zone.at(params[:until].to_i + 1) : Time.current
  end

  def ensure_cakto_sla_enabled
    raise ActiveRecord::RecordNotFound unless Current.account.feature_enabled?('cakto_sla')
  end

  def check_authorization
    authorize :report, :view?
  end
end
