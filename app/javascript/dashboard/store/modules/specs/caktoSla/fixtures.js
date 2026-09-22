export const policies = [
  {
    id: 1,
    name: 'Suporte padrão',
    description: '',
    first_response_minutes: 15,
    resolution_minutes: 480,
    inbox_ids: [1, 2],
    active: true,
    created_at: 1790000000,
    updated_at: 1790000000,
  },
  {
    id: 2,
    name: 'Financeiro',
    description: 'Cobranças e estornos',
    first_response_minutes: null,
    resolution_minutes: 1440,
    inbox_ids: [3],
    active: false,
    created_at: 1790000000,
    updated_at: 1790000000,
  },
];

export const report = {
  totals: {
    conversations: 120,
    first_response: { measured: 110, met: 90, breached: 15, pending: 5 },
    resolution: { measured: 110, met: 70, breached: 30, pending: 10 },
  },
  by_inbox: [],
  by_agent: [],
};
