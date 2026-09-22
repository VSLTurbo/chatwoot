/* global axios */
import ApiClient from './ApiClient';

class CaktoSlaAPI extends ApiClient {
  constructor() {
    super('cakto_sla_policies', { accountScoped: true });
  }

  report(params) {
    return axios.get(`${this.baseUrl()}/cakto_sla/report`, { params });
  }
}

export default new CaktoSlaAPI();
