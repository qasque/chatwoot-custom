<script setup>
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TelegramReportSettingApi from 'dashboard/api/telegramReportSetting';

const { t } = useI18n();

const loading = ref(true);
const saving = ref(false);
const sending = ref(false);
const loadError = ref('');
const setting = ref({
  schedule_hour: 9,
  schedule_minute: 0,
  timezone: 'Europe/Moscow',
  inbox_ids: [],
});
const inboxes = ref([]);
const timezones = ref([]);
const periodStart = ref('');
const periodEnd = ref('');
const sendInboxIds = ref([]);

const sortedInboxes = computed(() =>
  [...(inboxes.value || [])].sort((a, b) =>
    (a.name || '').localeCompare(b.name || '', undefined, {
      sensitivity: 'base',
    })
  )
);

function toggleScheduleInbox(id) {
  const set = new Set(setting.value.inbox_ids || []);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  setting.value = { ...setting.value, inbox_ids: [...set] };
}

function toggleSendInbox(id) {
  const set = new Set(sendInboxIds.value);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  sendInboxIds.value = [...set];
}

async function load() {
  loading.value = true;
  loadError.value = '';
  try {
    const { data } = await TelegramReportSettingApi.get();
    setting.value = {
      schedule_hour: data.telegram_report_setting.schedule_hour,
      schedule_minute: data.telegram_report_setting.schedule_minute,
      timezone: data.telegram_report_setting.timezone,
      inbox_ids: data.telegram_report_setting.inbox_ids || [],
    };
    inboxes.value = data.inboxes || [];
    timezones.value = data.timezones || [];
  } catch (e) {
    if (e.response?.status === 403) {
      loadError.value = t('TELEGRAM_REPORT.FORBIDDEN');
    } else {
      loadError.value = t('TELEGRAM_REPORT.LOAD_ERROR');
    }
  } finally {
    loading.value = false;
  }
}

async function saveSchedule() {
  saving.value = true;
  try {
    await TelegramReportSettingApi.update({
      schedule_hour: Number(setting.value.schedule_hour),
      schedule_minute: Number(setting.value.schedule_minute),
      timezone: setting.value.timezone,
      inbox_ids: setting.value.inbox_ids,
    });
    useAlert(t('TELEGRAM_REPORT.SAVE_SUCCESS'));
  } catch (e) {
    const msg =
      e.response?.data?.errors?.join?.(', ') ||
      e.response?.data?.error ||
      t('TELEGRAM_REPORT.SAVE_ERROR');
    useAlert(msg);
  } finally {
    saving.value = false;
  }
}

async function sendNow() {
  if (!periodStart.value || !periodEnd.value) {
    useAlert(t('TELEGRAM_REPORT.PERIOD_REQUIRED'));
    return;
  }
  sending.value = true;
  try {
    await TelegramReportSettingApi.sendNow({
      period_start: periodStart.value,
      period_end: periodEnd.value,
      inbox_ids: sendInboxIds.value,
    });
    useAlert(t('TELEGRAM_REPORT.SEND_SUCCESS'));
  } catch (e) {
    const msg = e.response?.data?.error || t('TELEGRAM_REPORT.SEND_ERROR');
    useAlert(msg);
  } finally {
    sending.value = false;
  }
}

onMounted(() => {
  load();
});
</script>

<template>
  <div class="flex flex-col flex-1 gap-6 p-6 overflow-auto">
    <BaseSettingsHeader
      :title="$t('TELEGRAM_REPORT.PAGE_TITLE')"
      :description="$t('TELEGRAM_REPORT.PAGE_DESC')"
    />

    <div v-if="loading" class="text-sm text-n-slate-11">
      {{ $t('TELEGRAM_REPORT.LOADING') }}
    </div>

    <div v-else-if="loadError" class="text-sm text-n-ruby-9 max-w-3xl">
      {{ loadError }}
    </div>

    <div v-else class="flex flex-col gap-8 max-w-3xl">
      <section class="flex flex-col gap-4 rounded-lg border border-n-weak bg-n-solid-2 p-4">
        <h2 class="text-sm font-medium text-n-slate-12 m-0">
          {{ $t('TELEGRAM_REPORT.SCHEDULE_TITLE') }}
        </h2>
        <p class="text-xs text-n-slate-11 m-0">
          {{ $t('TELEGRAM_REPORT.SCHEDULE_HINT') }}
        </p>
        <div class="flex flex-wrap gap-4 items-end">
          <div>
            <label class="block text-xs text-n-slate-11 mb-1">{{
              $t('TELEGRAM_REPORT.HOUR')
            }}</label>
            <input
              v-model.number="setting.schedule_hour"
              type="number"
              min="0"
              max="23"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1.5 text-sm w-24"
            />
          </div>
          <div>
            <label class="block text-xs text-n-slate-11 mb-1">{{
              $t('TELEGRAM_REPORT.MINUTE')
            }}</label>
            <input
              v-model.number="setting.schedule_minute"
              type="number"
              min="0"
              max="59"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1.5 text-sm w-24"
            />
          </div>
          <div class="flex-1 min-w-[12rem]">
            <label class="block text-xs text-n-slate-11 mb-1">{{
              $t('TELEGRAM_REPORT.TIMEZONE')
            }}</label>
            <select
              v-model="setting.timezone"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1.5 text-sm w-full max-w-md"
            >
              <option v-for="tz in timezones" :key="tz" :value="tz">
                {{ tz }}
              </option>
            </select>
          </div>
        </div>
        <div>
          <span class="block text-xs text-n-slate-11 mb-2">{{
            $t('TELEGRAM_REPORT.INBOXES_LABEL')
          }}</span>
          <ul
            class="flex flex-col gap-2 max-h-56 overflow-y-auto rounded-md border border-n-weak p-3"
          >
            <li
              v-for="inbox in sortedInboxes"
              :key="inbox.id"
              class="flex gap-2 items-center text-sm"
            >
              <input
                :id="`tg-sched-${inbox.id}`"
                type="checkbox"
                :checked="setting.inbox_ids.includes(inbox.id)"
                @change="toggleScheduleInbox(inbox.id)"
              />
              <label :for="`tg-sched-${inbox.id}`" class="m-0 cursor-pointer">{{
                inbox.name
              }}</label>
            </li>
          </ul>
        </div>
        <NextButton :is-loading="saving" @click="saveSchedule">
          {{ $t('TELEGRAM_REPORT.SAVE') }}
        </NextButton>
      </section>

      <section class="flex flex-col gap-4 rounded-lg border border-n-weak bg-n-solid-2 p-4">
        <h2 class="text-sm font-medium text-n-slate-12 m-0">
          {{ $t('TELEGRAM_REPORT.SEND_NOW_TITLE') }}
        </h2>
        <p class="text-xs text-n-slate-11 m-0">
          {{ $t('TELEGRAM_REPORT.SEND_NOW_HINT') }}
        </p>
        <div class="flex flex-wrap gap-4">
          <div>
            <label class="block text-xs text-n-slate-11 mb-1">{{
              $t('TELEGRAM_REPORT.PERIOD_START')
            }}</label>
            <input
              v-model="periodStart"
              type="datetime-local"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1.5 text-sm"
            />
          </div>
          <div>
            <label class="block text-xs text-n-slate-11 mb-1">{{
              $t('TELEGRAM_REPORT.PERIOD_END')
            }}</label>
            <input
              v-model="periodEnd"
              type="datetime-local"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1.5 text-sm"
            />
          </div>
        </div>
        <div v-if="sortedInboxes.length">
          <span class="block text-xs text-n-slate-11 mb-2">{{
            $t('TELEGRAM_REPORT.SEND_INBOXES')
          }}</span>
          <ul
            class="flex flex-col gap-2 max-h-40 overflow-y-auto rounded-md border border-n-weak p-3"
          >
            <li
              v-for="inbox in sortedInboxes"
              :key="`send-${inbox.id}`"
              class="flex gap-2 items-center text-sm"
            >
              <input
                :id="`tg-send-${inbox.id}`"
                type="checkbox"
                :checked="sendInboxIds.includes(inbox.id)"
                @change="toggleSendInbox(inbox.id)"
              />
              <label :for="`tg-send-${inbox.id}`" class="m-0 cursor-pointer">{{
                inbox.name
              }}</label>
            </li>
          </ul>
        </div>
        <NextButton color="slate" :is-loading="sending" @click="sendNow">
          {{ $t('TELEGRAM_REPORT.SEND_BUTTON') }}
        </NextButton>
      </section>
    </div>
  </div>
</template>
