import types from '../../../mutation-types';
import { mutations, getters } from '../../caktoSla';
import { policies, report } from './fixtures';

describe('caktoSla mutations', () => {
  it('SET_CAKTO_SLA_POLICIES', () => {
    const state = { records: [] };
    mutations[types.SET_CAKTO_SLA_POLICIES](state, policies);
    expect(state.records).toEqual(policies);
  });
  it('ADD_CAKTO_SLA_POLICY', () => {
    const state = { records: [policies[0]] };
    mutations[types.ADD_CAKTO_SLA_POLICY](state, policies[1]);
    expect(state.records).toEqual(policies);
  });
  it('EDIT_CAKTO_SLA_POLICY', () => {
    const state = { records: [policies[0]] };
    mutations[types.EDIT_CAKTO_SLA_POLICY](state, { id: 1, name: 'Novo' });
    expect(state.records[0].name).toEqual('Novo');
  });
  it('DELETE_CAKTO_SLA_POLICY', () => {
    const state = { records: [policies[0]] };
    mutations[types.DELETE_CAKTO_SLA_POLICY](state, 1);
    expect(state.records).toEqual([]);
  });
  it('SET_CAKTO_SLA_REPORT e SET_CAKTO_SLA_UI_FLAG', () => {
    const state = { report: null, uiFlags: { isFetching: false } };
    mutations[types.SET_CAKTO_SLA_REPORT](state, report);
    mutations[types.SET_CAKTO_SLA_UI_FLAG](state, { isFetching: true });
    expect(getters.getReport(state)).toEqual(report);
    expect(getters.getUIFlags(state)).toEqual({ isFetching: true });
  });
});
