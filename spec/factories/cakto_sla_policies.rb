# frozen_string_literal: true

FactoryBot.define do
  factory :cakto_sla_policy do
    account
    sequence(:name) { |n| "Política #{n}" }
    first_response_minutes { 15 }
    resolution_minutes { 480 }
    inbox_ids { [] }
    active { true }
  end
end
