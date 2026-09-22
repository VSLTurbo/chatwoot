# frozen_string_literal: true

FactoryBot.define do
  factory :cakto_conversation_sla do
    account
    conversation { association :conversation, account: account }
    cakto_sla_policy { association :cakto_sla_policy, account: account }
    first_response_due_at { 15.minutes.from_now }
    resolution_due_at { 8.hours.from_now }
    first_response_status { :pending }
    resolution_status { :pending }
  end
end
