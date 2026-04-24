<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../settings/components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import OutageAutoReplyApi from 'dashboard/api/outageAutoReply';

const { t } = useI18n();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');
const uiFlags = useMapGetter('inboxes/getUIFlags');

const enabled = ref(false);
const messageBody = ref('');
const selectedInboxIds = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);

/** API/i18n иногда отдают null — `.trim()` на null бросает в UI */
function asOutageText(raw) {
  if (raw != null && String(raw).trim() !== '') return String(raw);
  return String(t('OUTAGE_AUTO_REPLY.DEFAULT_MESSAGE') || '');
}

const sortedInboxes = computed(() =>
  [...(inboxes.value || [])].sort((a, b) =>
    (a.name || '').localeCompare(b.name || '', undefined, {
      sensitivity: 'base',
    })
  )
);

function toggleInbox(id) {
  const set = new Set(selectedInboxIds.value);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  selectedInboxIds.value = [...set];
}

function selectAll() {
  selectedInboxIds.value = sortedInboxes.value.map(i => i.id);
}

function clearSelection() {
  selectedInboxIds.value = [];
}

async function load() {
  isLoading.value = true;
  try {
    const { data } = await OutageAutoReplyApi.get();
    enabled.value = !!data.enabled;
    messageBody.value = asOutageText(data?.message);
    selectedInboxIds.value = Array.isArray(data.inbox_ids)
      ? [...data.inbox_ids]
      : [];
  } catch (e) {
    useAlert(t('OUTAGE_AUTO_REPLY.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
}

async function save() {
  if (enabled.value) {
    if (!selectedInboxIds.value.length) {
      useAlert(t('OUTAGE_AUTO_REPLY.VALIDATION_INBOXES'));
      return;
    }
    const userMsg = String(messageBody.value ?? '').trim();
    if (!userMsg) {
      useAlert(t('OUTAGE_AUTO_REPLY.VALIDATION_MESSAGE'));
      return;
    }
  }

  isSaving.value = true;
  try {
    const res = await OutageAutoReplyApi.update({
      enabled: enabled.value,
      message: String(messageBody.value ?? '').trim(),
      inbox_ids: selectedInboxIds.value,
    });
    const data = res.data || {};
    enabled.value = !!data.enabled;
    messageBody.value = asOutageText(data?.message);
    selectedInboxIds.value = Array.isArray(data.inbox_ids)
      ? [...data.inbox_ids]
      : [];
    useAlert(t('OUTAGE_AUTO_REPLY.SAVE_SUCCESS'));
  } catch (e) {
    const fromApi = e?.response?.data?.error;
    const fromErr = e?.message;
    useAlert(fromApi || fromErr || t('OUTAGE_AUTO_REPLY.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
}

onMounted(() => {
  if (!inboxes.value?.length) {
    store.dispatch('inboxes/get');
  }
  load();
});
</script>

<template>
  <div class="flex flex-col flex-1 gap-6 p-6 overflow-auto">
    <BaseSettingsHeader
      :title="$t('OUTAGE_AUTO_REPLY.PAGE_TITLE')"
      :description="$t('OUTAGE_AUTO_REPLY.PAGE_DESC')"
    />

    <div v-if="isLoading || uiFlags.isFetching" class="text-sm text-n-slate-11">
      {{ $t('OUTAGE_AUTO_REPLY.LOADING') }}
    </div>

    <div v-else class="flex flex-col gap-6 max-w-3xl">
      <label class="flex gap-3 items-center cursor-pointer">
        <input
          v-model="enabled"
          type="checkbox"
          class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('OUTAGE_AUTO_REPLY.TOGGLE_LABEL') }}
        </span>
      </label>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">{{
          $t('OUTAGE_AUTO_REPLY.INBOXES_LABEL')
        }}</label>
        <p class="text-xs text-n-slate-11">
          {{ $t('OUTAGE_AUTO_REPLY.INBOXES_HINT') }}
        </p>
        <div class="flex gap-2 mb-2">
          <NextButton ghost sm @click="selectAll">
            {{ $t('OUTAGE_AUTO_REPLY.SELECT_ALL_INBOXES') }}
          </NextButton>
          <NextButton ghost sm @click="clearSelection">
            {{ $t('OUTAGE_AUTO_REPLY.CLEAR_SELECTION') }}
          </NextButton>
        </div>
        <ul
          class="flex flex-col gap-2 max-h-64 overflow-y-auto rounded-lg border border-n-weak bg-n-solid-2 p-3"
        >
          <li
            v-for="inbox in sortedInboxes"
            :key="inbox.id"
            class="flex gap-2 items-center"
          >
            <input
              :id="`oar-inbox-${inbox.id}`"
              type="checkbox"
              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
              :checked="selectedInboxIds.includes(inbox.id)"
              @change="toggleInbox(inbox.id)"
            />
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -- inbox name from API -->
            <label
              :for="`oar-inbox-${inbox.id}`"
              class="text-sm text-n-slate-12 cursor-pointer"
            >
              {{ inbox.name }}
            </label>
          </li>
        </ul>
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">{{
          $t('OUTAGE_AUTO_REPLY.MESSAGE_LABEL')
        }}</label>
        <textarea
          v-model="messageBody"
          rows="5"
          class="rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
        />
      </div>

      <NextButton :is-loading="isSaving" @click="save">
        {{ $t('OUTAGE_AUTO_REPLY.SAVE') }}
      </NextButton>
    </div>
  </div>
</template>
