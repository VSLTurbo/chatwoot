/* global axios */
import ApiClient from '../ApiClient';

class EnterpriseAccountAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true, enterprise: true });
  }

  toggleDeletion(action) {
    return axios.post(`${this.url}toggle_deletion`, {
      action_type: action,
    });
  }
}

export default new EnterpriseAccountAPI();
