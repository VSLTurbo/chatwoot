class Api::V1::Accounts::CaktoSla::ReportsController < Api::V1::Accounts::BaseController
  before_action :ensure_cakto_sla_enabled
  before_action :check_authorization

  def show
    render json: ::CaktoSla::ReportService.new(
      account: Current.account,
      from: params[:since].present? ? Time.zone.at(params[:since].to_i) : 7.days.ago,
      to: params[:until].present? ? Time.zone.at(params[:until].to_i) : Time.current,
      inbox_id: params[:inbox_id]
    ).perform
  end

  private

  def ensure_cakto_sla_enabled
    raise ActiveRecord::RecordNotFound unless Current.account.feature_enabled?('cakto_sla')
  end

  def check_authorization
    authorize :report, :view?
  end
end
