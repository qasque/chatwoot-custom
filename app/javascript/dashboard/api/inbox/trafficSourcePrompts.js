/* global axios */
import ApiClient from 'dashboard/api/ApiClient';

class TrafficSourcePromptsApi extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  basePath(inboxId) {
    return `${this.baseUrl()}/inboxes/${inboxId}/traffic_source_prompts`;
  }

  list(inboxId) {
    return axios.get(this.basePath(inboxId));
  }

  getCurrent(inboxId, sourceId) {
    return axios.get(`${this.basePath(inboxId)}/current`, {
      params: { source_id: sourceId },
    });
  }

  upload(inboxId, sourceId, file) {
    const formData = new FormData();
    formData.append('source_id', sourceId);
    formData.append('file', file);
    return axios.post(this.basePath(inboxId), formData);
  }

  download(inboxId, sourceId) {
    return axios.get(`${this.basePath(inboxId)}/download`, {
      params: { source_id: sourceId },
      responseType: 'blob',
    });
  }
}

export default new TrafficSourcePromptsApi();
