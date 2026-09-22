import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import CaktoSlaAPI from '../../api/caktoSla';

export const state = {
  records: [],
  report: null,
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isFetchingReport: false,
  },
};

export const getters = {
  getPolicies(_state) {
    return _state.records;
  },
  getReport(_state) {
    return _state.report;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

// A lista pode vir crua ou dentro de `payload`, como o resto da API.
const listFrom = data => (Array.isArray(data) ? data : data?.payload || []);

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_CAKTO_SLA_UI_FLAG, { isFetching: true });
    try {
      const response = await CaktoSlaAPI.get();
      commit(types.SET_CAKTO_SLA_POLICIES, listFrom(response.data));
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CAKTO_SLA_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, policy) => {
    commit(types.SET_CAKTO_SLA_UI_FLAG, { isCreating: true });
    try {
      const response = await CaktoSlaAPI.create({ cakto_sla_policy: policy });
      commit(types.ADD_CAKTO_SLA_POLICY, response.data);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_CAKTO_SLA_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, ...policy }) => {
    commit(types.SET_CAKTO_SLA_UI_FLAG, { isUpdating: true });
    try {
      const response = await CaktoSlaAPI.update(id, {
        cakto_sla_policy: policy,
      });
      commit(types.EDIT_CAKTO_SLA_POLICY, response.data);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_CAKTO_SLA_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_CAKTO_SLA_UI_FLAG, { isDeleting: true });
    try {
      await CaktoSlaAPI.delete(id);
      commit(types.DELETE_CAKTO_SLA_POLICY, id);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_CAKTO_SLA_UI_FLAG, { isDeleting: false });
    }
  },

  fetchReport: async ({ commit }, params) => {
    commit(types.SET_CAKTO_SLA_UI_FLAG, { isFetchingReport: true });
    try {
      const response = await CaktoSlaAPI.report(params);
      commit(types.SET_CAKTO_SLA_REPORT, response.data);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_CAKTO_SLA_UI_FLAG, { isFetchingReport: false });
    }
  },
};

export const mutations = {
  [types.SET_CAKTO_SLA_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_CAKTO_SLA_REPORT](_state, report) {
    _state.report = report;
  },
  [types.SET_CAKTO_SLA_POLICIES]: MutationHelpers.set,
  [types.ADD_CAKTO_SLA_POLICY]: MutationHelpers.create,
  [types.EDIT_CAKTO_SLA_POLICY]: MutationHelpers.update,
  [types.DELETE_CAKTO_SLA_POLICY]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
