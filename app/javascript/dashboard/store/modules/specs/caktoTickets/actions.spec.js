import axios from 'axios';
import { actions } from '../../caktoTickets';
import types from '../../../mutation-types';
import { setup, ticket } from './fixtures';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('caktoTickets actions', () => {
  beforeEach(() => commit.mockClear());

  describe('#fetchSetup', () => {
    it('busca a caixa e as equipes', async () => {
      axios.get.mockResolvedValue({ data: setup });
      await actions.fetchSetup({ commit });
      expect(axios.get).toHaveBeenCalledWith('/api/v1/cakto_tickets/setup');
      expect(commit.mock.calls).toEqual([
        [types.SET_CAKTO_TICKETS_UI_FLAG, { isFetchingSetup: true }],
        [types.SET_CAKTO_TICKETS_SETUP, setup],
        [types.SET_CAKTO_TICKETS_UI_FLAG, { isFetchingSetup: false }],
      ]);
    });
    it('lança erro e limpa a flag', async () => {
      axios.get.mockRejectedValue({ message: 'erro' });
      await expect(actions.fetchSetup({ commit })).rejects.toThrow('erro');
      expect(commit.mock.calls[1]).toEqual([
        types.SET_CAKTO_TICKETS_UI_FLAG,
        { isFetchingSetup: false },
      ]);
    });
  });

  describe('#create', () => {
    it('envolve o corpo em cakto_ticket e devolve a conversa', async () => {
      axios.post.mockResolvedValue({ data: ticket });
      const payload = { team_id: 2, title: 'Estorno', description: 'x' };
      const data = await actions.create({ commit }, payload);
      expect(axios.post).toHaveBeenCalledWith('/api/v1/cakto_tickets', {
        cakto_ticket: payload,
      });
      expect(data).toEqual(ticket);
      expect(commit.mock.calls).toEqual([
        [types.SET_CAKTO_TICKETS_UI_FLAG, { isCreating: true }],
        [types.SET_CAKTO_TICKETS_UI_FLAG, { isCreating: false }],
      ]);
    });
    it('propaga a mensagem do 422', async () => {
      axios.post.mockRejectedValue({
        response: { data: { message: 'Título é obrigatório' } },
      });
      await expect(actions.create({ commit }, {})).rejects.toThrow(
        'Título é obrigatório'
      );
    });
  });
});
