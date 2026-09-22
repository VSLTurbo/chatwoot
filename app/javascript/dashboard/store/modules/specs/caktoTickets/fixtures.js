export const setup = {
  inbox_id: 7,
  teams: [
    { id: 1, name: 'Suporte' },
    { id: 2, name: 'Compliance' },
  ],
};

export const ticket = {
  id: 321,
  account_id: 1,
  inbox_id: 7,
  team_id: 2,
  priority: 'high',
  additional_attributes: { cakto_ticket: true, solicitante_user_id: 5 },
};
