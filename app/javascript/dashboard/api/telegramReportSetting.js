/* global axios */
import ApiClient from './ApiClient';

class TelegramReportSettingApi extends ApiClient {
  constructor() {
    super('telegram_report_setting', { accountScoped: true });
  }

  update(payload) {
    return axios.patch(this.url, { telegram_report_setting: payload });
  }

  sendNow(payload) {
    return axios.post(`${this.url}/send_now`, payload);
  }
}

export default new TelegramReportSettingApi();
