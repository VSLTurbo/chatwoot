class CaktoTicketPolicy < ApplicationPolicy
  def create?
    @account_user.administrator? || @account_user.agent?
  end

  def setup?
    create?
  end
end
