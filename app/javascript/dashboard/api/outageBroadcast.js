/* global axios */
import ApiClient from './ApiClient';

class OutageBroadcastApi extends ApiClient {
  constructor() {
    super('outage_broadcast', { accountScoped: true });
  }

  create(payload) {
    return axios.post(this.url, { outage_broadcast: payload });
  }
}

export default new OutageBroadcastApi();
