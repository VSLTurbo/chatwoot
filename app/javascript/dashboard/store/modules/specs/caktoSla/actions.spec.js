import axios from 'axios';
import { actions } from '../../caktoSla';
import types from '../../../mutation-types';
import { policies, report } from './fixtures';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('caktoSla actions', () => {
  beforeEach(() => commit.mockClear());

  describe('#get', () => {
    it('aceita lista crua', async () => {
      axios.get.mockResolvedValue({ data: policies });
      await actions.get({ commit });
      expect(commit.mock.calls).toEqual([
        [types.SET_CAKTO_SLA_UI_FLAG, { isFetching: true }],
        [types.SET_CAKTO_SLA_POLICIES, policies],
        [types.SET_CAKTO_SLA_UI_FLAG, { isFetching: false }],
      ]);
    });
    it('aceita lista em payload', async () => {
      axios.get.mockResolvedValue({ data: { payload: policies } });
      await actions.get({ commit });
      expect(commit.mock.calls[1]).toEqual([
        types.SET_CAKTO_SLA_POLICIES,
        policies,
      ]);
    });
    it('engole erro e limpa a flag', async () => {
      axios.get.mockRejectedValue({ message: 'erro' });
      await actions.get({ commit });
      expect(commit.mock.calls).toEqual([
        [types.SET_CAKTO_SLA_UI_FLAG, { isFetching: true }],
        [types.SET_CAKTO_SLA_UI_FLAG, { isFetching: false }],
      ]);
    });
  });

  describe('#create', () => {
    it('envolve o corpo em cakto_sla_policy', async () => {
      axios.post.mockResolvedValue({ data: policies[0] });
      await actions.create({ commit }, { name: 'Suporte padrão' });
      expect(axios.post).toHaveBeenCalledWith('/api/v1/cakto_sla_policies', {
        cakto_sla_policy: { name: 'Suporte padrão' },
      });
      expect(commit.mock.calls).toEqual([
        [types.SET_CAKTO_SLA_UI_FLAG, { isCreating: true }],
        [types.ADD_CAKTO_SLA_POLICY, policies[0]],
        [types.SET_CAKTO_SLA_UI_FLAG, { isCreating: false }],
      ]);
    });
    it('propaga a mensagem da API', async () => {
      axios.post.mockRejectedValue({
        response: { data: { message: 'Caixa já coberta' } },
      });
      await expect(actions.create({ commit }, {})).rejects.toThrow(
        'Caixa já coberta'
      );
    });
  });

  describe('#update', () => {
    it('envia patch com id fora do corpo', async () => {
      axios.patch.mockResolvedValue({ data: policies[0] });
      await actions.update({ commit }, { id: 1, active: false });
      expect(axios.patch).toHaveBeenCalledWith('/api/v1/cakto_sla_policies/1', {
        cakto_sla_policy: { active: false },
      });
      expect(commit.mock.calls[1]).toEqual([
        types.EDIT_CAKTO_SLA_POLICY,
        policies[0],
      ]);
    });
  });

  describe('#delete', () => {
    it('remove do store', async () => {
      axios.delete.mockResolvedValue({});
      await actions.delete({ commit }, 1);
      expect(commit.mock.calls).toEqual([
        [types.SET_CAKTO_SLA_UI_FLAG, { isDeleting: true }],
        [types.DELETE_CAKTO_SLA_POLICY, 1],
        [types.SET_CAKTO_SLA_UI_FLAG, { isDeleting: false }],
      ]);
    });
    it('lança erro', async () => {
      axios.delete.mockRejectedValue({ message: 'erro' });
      await expect(actions.delete({ commit }, 1)).rejects.toThrow(Error);
    });
  });

  describe('#fetchReport', () => {
    it('busca com os parâmetros e guarda', async () => {
      axios.get.mockResolvedValue({ data: report });
      const params = { since: 1, until: 2, inbox_id: 3 };
      await actions.fetchReport({ commit }, params);
      expect(axios.get).toHaveBeenCalledWith('/api/v1/cakto_sla/report', {
        params,
      });
      expect(commit.mock.calls).toEqual([
        [types.SET_CAKTO_SLA_UI_FLAG, { isFetchingReport: true }],
        [types.SET_CAKTO_SLA_REPORT, report],
        [types.SET_CAKTO_SLA_UI_FLAG, { isFetchingReport: false }],
      ]);
    });
  });
});
