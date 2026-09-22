/* global axios */
import ApiClient from './ApiClient';

class CaktoTicketsAPI extends ApiClient {
  constructor() {
    super('cakto_tickets', { accountScoped: true });
  }

  create(payload) {
    return axios.post(this.url, { cakto_ticket: payload });
  }

  setup() {
    return axios.get(`${this.url}/setup`);
  }
}

export default new CaktoTicketsAPI();
