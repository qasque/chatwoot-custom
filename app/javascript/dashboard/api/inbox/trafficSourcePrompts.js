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
    const params = {};
    if (sourceId) params.source_id = sourceId;
    return axios.get(`${this.basePath(inboxId)}/current`, {
      params,
    });
  }

  upload(inboxId, sourceId, file) {
    const formData = new FormData();
    if (sourceId) formData.append('source_id', sourceId);
    formData.append('file', file);
    return axios.post(this.basePath(inboxId), formData);
  }

  download(inboxId, sourceId) {
    const params = {};
    if (sourceId) params.source_id = sourceId;
    return axios.get(`${this.basePath(inboxId)}/download`, {
      params,
      responseType: 'blob',
    });
  }

  remove(inboxId, sourceId) {
    const params = {};
    if (sourceId) params.source_id = sourceId;
    return axios.delete(this.basePath(inboxId), { params });
  }
}

export default new TrafficSourcePromptsApi();
