import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/cakto-sla'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'cakto_sla_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: to => {
            return { name: 'cakto_sla_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'cakto_sla_list',
          meta: {
            featureFlag: FEATURE_FLAGS.CAKTO_SLA,
            permissions: ['administrator'],
          },
          component: Index,
        },
      ],
    },
  ],
};
