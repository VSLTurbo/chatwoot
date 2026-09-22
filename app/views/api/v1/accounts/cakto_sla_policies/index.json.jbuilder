json.array! @cakto_sla_policies do |cakto_sla_policy|
  json.partial! 'api/v1/models/cakto_sla_policy', formats: [:json], resource: cakto_sla_policy
end
