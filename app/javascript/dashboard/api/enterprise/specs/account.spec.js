import accountAPI from '../account';
import ApiClient from '../../ApiClient';

describe('#enterpriseAccountAPI', () => {
  it('creates correct instance', () => {
    expect(accountAPI).toBeInstanceOf(ApiClient);
    expect(accountAPI).toHaveProperty('toggleDeletion');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#toggleDeletion', () => {
      accountAPI.toggleDeletion('delete');
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/enterprise/api/v1/toggle_deletion',
        { action_type: 'delete' }
      );
    });
  });
});
