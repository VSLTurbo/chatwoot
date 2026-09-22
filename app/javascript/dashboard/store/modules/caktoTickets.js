import types from '../mutation-types';
import CaktoTicketsAPI from '../../api/caktoTickets';

export const state = {
  teams: [],
  inboxId: null,
  uiFlags: {
    isFetchingSetup: false,
    isCreating: false,
  },
};

export const getters = {
  getTeams(_state) {
    return _state.teams;
  },
  getInboxId(_state) {
    return _state.inboxId;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  fetchSetup: async ({ commit }) => {
    commit(types.SET_CAKTO_TICKETS_UI_FLAG, { isFetchingSetup: true });
    try {
      const response = await CaktoTicketsAPI.setup();
      commit(types.SET_CAKTO_TICKETS_SETUP, response.data);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_CAKTO_TICKETS_UI_FLAG, { isFetchingSetup: false });
    }
  },

  // Devolve a conversa criada (jbuilder padrão), para navegar por `id`.
  create: async ({ commit }, ticket) => {
    commit(types.SET_CAKTO_TICKETS_UI_FLAG, { isCreating: true });
    try {
      const response = await CaktoTicketsAPI.create(ticket);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_CAKTO_TICKETS_UI_FLAG, { isCreating: false });
    }
  },
};

export const mutations = {
  [types.SET_CAKTO_TICKETS_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_CAKTO_TICKETS_SETUP](_state, { inbox_id: inboxId, teams }) {
    _state.inboxId = inboxId ?? null;
    _state.teams = teams || [];
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
