<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import { formatTaskNoteMessage } from 'dashboard/helper/taskNotes';

const emit = defineEmits(['created']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const searchQuery = ref('');
const taskBody = ref('');
const selectedId = ref(null);
const isSubmitting = ref(false);

const searchResults = computed(
  () => store.getters['conversationSearch/getConversationRecords'] || []
);
const searchUi = useMapGetter('conversationSearch/getUIFlags');
const isSearchFetching = computed(
  () => searchUi.value?.conversation?.isFetching === true
);

const resetForm = () => {
  searchQuery.value = '';
  taskBody.value = '';
  selectedId.value = null;
  store.dispatch('conversationSearch/clearSearchResults');
};

const open = () => {
  resetForm();
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
  resetForm();
};

const runSearch = async q => {
  await store.dispatch('conversationSearch/clearSearchResults');
  if (!q || q.trim().length < 2) return;
  await store.dispatch('conversationSearch/conversationSearch', {
    q: q.trim(),
    page: 1,
  });
};

const debouncedSearch = useDebounceFn(runSearch, 320);

watch(searchQuery, v => {
  debouncedSearch(v);
});

const pickConversation = row => {
  selectedId.value = row.id;
};

const rowLabel = row => {
  const sender = row?.meta?.sender;
  if (sender?.name) return sender.name;
  if (row?.id) return `#${row.id}`;
  return '—';
};

const onSubmit = async () => {
  if (!selectedId.value) {
    useAlert(t('CONVERSATION.QUICK_TASK.SELECT_CONVERSATION_WARNING'));
    return;
  }
  const body = taskBody.value.trim();
  if (!body) {
    useAlert(t('CONVERSATION.QUICK_TASK.TASK_REQUIRED'));
    return;
  }
  isSubmitting.value = true;
  try {
    await store.dispatch('createPendingMessageAndSend', {
      conversationId: selectedId.value,
      message: formatTaskNoteMessage(body),
      private: true,
    });
    useAlert(t('CONVERSATION.QUICK_TASK.SUCCESS'));
    emit('created');
    close();
  } catch (e) {
    const msg =
      e?.response?.data?.error || t('CONVERSATION.QUICK_TASK.ERROR_GENERIC');
    useAlert(msg);
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="lg"
    :show-confirm-button="false"
    :show-cancel-button="false"
    :title="t('CONVERSATION.QUICK_TASK.MODAL_TITLE')"
    :description="t('CONVERSATION.QUICK_TASK.MODAL_DESC')"
    @close="resetForm"
  >
    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-n-slate-11">{{
          t('CONVERSATION.QUICK_TASK.SEARCH_LABEL')
        }}</label>
        <input
          v-model="searchQuery"
          type="search"
          autocomplete="off"
          class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          :placeholder="t('CONVERSATION.QUICK_TASK.SEARCH_PLACEHOLDER')"
        />
        <div
          v-if="searchResults.length"
          class="max-h-40 overflow-y-auto rounded-lg border border-n-weak bg-n-solid-2/80"
        >
          <button
            v-for="row in searchResults"
            :key="row.id"
            type="button"
            class="flex w-full items-center justify-between gap-2 px-3 py-2 text-left text-sm transition-colors hover:bg-n-alpha-2"
            :class="
              selectedId === row.id ? 'bg-n-brand/15 text-n-slate-12' : ''
            "
            @click="pickConversation(row)"
          >
            <span class="truncate font-medium">{{ rowLabel(row) }}</span>
            <span class="flex-shrink-0 text-n-slate-11 text-xs">
              #{{ row.id }}
            </span>
          </button>
        </div>
        <p
          v-else-if="
            searchQuery.trim().length > 1 &&
            !isSearchFetching &&
            !searchResults.length
          "
          class="text-xs text-n-slate-11"
        >
          {{ t('CONVERSATION.QUICK_TASK.NO_RESULTS') }}
        </p>
      </div>
      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-n-slate-11">{{
          t('CONVERSATION.QUICK_TASK.TASK_LABEL')
        }}</label>
        <textarea
          v-model="taskBody"
          rows="3"
          class="w-full resize-none rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          :placeholder="t('CONVERSATION.QUICK_TASK.TASK_PLACEHOLDER')"
        />
      </div>
    </div>
    <template #footer>
      <div class="flex w-full gap-3">
        <Button
          variant="faded"
          color="slate"
          class="w-full"
          type="button"
          :label="t('DIALOG.BUTTONS.CANCEL')"
          @click="close"
        />
        <Button
          color="blue"
          class="w-full"
          type="button"
          :is-loading="isSubmitting"
          :disabled="isSubmitting"
          :label="t('CONVERSATION.QUICK_TASK.CREATE')"
          @click="onSubmit"
        />
      </div>
    </template>
  </Dialog>
</template>
