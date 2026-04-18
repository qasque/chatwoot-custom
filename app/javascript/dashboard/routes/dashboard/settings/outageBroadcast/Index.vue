<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import OutageBroadcastApi from 'dashboard/api/outageBroadcast';

const { t } = useI18n();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');
const uiFlags = useMapGetter('inboxes/getUIFlags');

const selectedInboxIds = ref([]);
const messageBody = ref('');
const isSubmitting = ref(false);
const confirmRef = ref(null);

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

onMounted(() => {
  messageBody.value = t('OUTAGE_BROADCAST.DEFAULT_MESSAGE');
  if (!inboxes.value?.length) {
    store.dispatch('inboxes/get');
  }
});

function openConfirm() {
  if (!selectedInboxIds.value.length) {
    useAlert(t('OUTAGE_BROADCAST.VALIDATION_INBOXES'));
    return;
  }
  if (!messageBody.value.trim()) {
    useAlert(t('OUTAGE_BROADCAST.VALIDATION_MESSAGE'));
    return;
  }
  confirmRef.value?.open();
}

async function submit() {
  isSubmitting.value = true;
  try {
    await OutageBroadcastApi.create({
      inbox_ids: selectedInboxIds.value,
      content: messageBody.value.trim(),
    });
    useAlert(t('OUTAGE_BROADCAST.SUCCESS'));
    confirmRef.value?.close();
  } catch (e) {
    const fromApi = e?.response?.data?.error;
    const fromErr = e?.message;
    useAlert(fromApi || fromErr || t('OUTAGE_BROADCAST.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<template>
  <div class="flex flex-col flex-1 gap-6 p-6 overflow-auto">
    <BaseSettingsHeader
      :title="$t('OUTAGE_BROADCAST.PAGE_TITLE')"
      :description="$t('OUTAGE_BROADCAST.PAGE_DESC')"
    />

    <div v-if="uiFlags.isFetching" class="text-sm text-n-slate-11">
      {{ $t('OUTAGE_BROADCAST.LOADING') }}
    </div>

    <div v-else class="flex flex-col gap-6 max-w-3xl">
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">{{
          $t('OUTAGE_BROADCAST.INBOXES_LABEL')
        }}</label>
        <p class="text-xs text-n-slate-11">
          {{ $t('OUTAGE_BROADCAST.INBOXES_HINT') }}
        </p>
        <div class="flex gap-2 mb-2">
          <NextButton ghost sm @click="selectAll">
            {{ $t('OUTAGE_BROADCAST.SELECT_ALL_INBOXES') }}
          </NextButton>
          <NextButton ghost sm @click="clearSelection">
            {{ $t('OUTAGE_BROADCAST.CLEAR_SELECTION') }}
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
              :id="`ob-inbox-${inbox.id}`"
              type="checkbox"
              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
              :checked="selectedInboxIds.includes(inbox.id)"
              @change="toggleInbox(inbox.id)"
            />
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -- inbox name from API -->
            <label
              :for="`ob-inbox-${inbox.id}`"
              class="text-sm cursor-pointer text-n-slate-12"
            >
              {{ inbox.name }}
            </label>
          </li>
        </ul>
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">{{
          $t('OUTAGE_BROADCAST.MESSAGE_LABEL')
        }}</label>
        <textarea
          v-model="messageBody"
          rows="5"
          class="w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand"
        />
      </div>

      <NextButton color="blue" :disabled="isSubmitting" @click="openConfirm">
        {{ $t('OUTAGE_BROADCAST.SUBMIT') }}
      </NextButton>
    </div>

    <Dialog
      ref="confirmRef"
      type="alert"
      :title="$t('OUTAGE_BROADCAST.CONFIRM_TITLE')"
      :description="$t('OUTAGE_BROADCAST.CONFIRM_BODY')"
      :confirm-button-label="$t('OUTAGE_BROADCAST.SUBMIT')"
      :is-loading="isSubmitting"
      @confirm="submit"
    />
  </div>
</template>
