import types from '../../../mutation-types';
import { mutations, getters } from '../../caktoTickets';
import { setup } from './fixtures';

describe('caktoTickets mutations', () => {
  it('SET_CAKTO_TICKETS_SETUP', () => {
    const state = { teams: [], inboxId: null };
    mutations[types.SET_CAKTO_TICKETS_SETUP](state, setup);
    expect(getters.getTeams(state)).toEqual(setup.teams);
    expect(getters.getInboxId(state)).toEqual(7);
  });
  it('SET_CAKTO_TICKETS_SETUP sem caixa ainda', () => {
    const state = { teams: [], inboxId: 3 };
    mutations[types.SET_CAKTO_TICKETS_SETUP](state, { inbox_id: null });
    expect(state).toEqual({ teams: [], inboxId: null });
  });
  it('SET_CAKTO_TICKETS_UI_FLAG', () => {
    const state = { uiFlags: { isCreating: false, isFetchingSetup: false } };
    mutations[types.SET_CAKTO_TICKETS_UI_FLAG](state, { isCreating: true });
    expect(getters.getUIFlags(state)).toEqual({
      isCreating: true,
      isFetchingSetup: false,
    });
  });
});
