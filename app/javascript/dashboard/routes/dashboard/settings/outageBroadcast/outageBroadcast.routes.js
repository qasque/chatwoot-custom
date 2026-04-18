import {
  CONVERSATION_PERMISSIONS,
  ROLES,
} from 'dashboard/constants/permissions.js';
import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/outage-broadcast'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_outage_broadcast_index',
          component: Index,
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
        },
      ],
    },
  ],
};
