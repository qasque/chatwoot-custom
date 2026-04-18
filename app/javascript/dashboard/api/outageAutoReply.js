/* global axios */
import ApiClient from './ApiClient';

class OutageAutoReplyApi extends ApiClient {
  constructor() {
    super('outage_auto_reply', { accountScoped: true });
  }

  update(payload) {
    return axios.patch(this.url, { outage_auto_reply: payload });
  }
}

export default new OutageAutoReplyApi();
