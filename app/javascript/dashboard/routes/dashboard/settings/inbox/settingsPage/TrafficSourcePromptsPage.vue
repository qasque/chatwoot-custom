<script>
import { useAlert } from 'dashboard/composables';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TrafficSourcePromptsAPI from 'dashboard/api/inbox/trafficSourcePrompts';

const ACCEPTED_EXTENSIONS = ['.txt', '.doc', '.docx', '.pdf'];

export default {
  components: {
    SettingsFieldSection,
    NextButton,
  },
  props: {
    inbox: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      sourceId: '',
      isAdvancedMode: false,
      sourceOptions: [],
      selectedFile: null,
      currentPrompt: null,
      isLoadingPrompt: false,
      isUploading: false,
      isDownloading: false,
      isDeleting: false,
    };
  },
  mounted() {
    this.fetchSourceOptions();
    this.loadCurrentPrompt();
  },
  methods: {
    displaySourceLabel(sourceId) {
      return sourceId || 'Default inbox prompt';
    },
    normalizedSourceId() {
      return this.sourceId.trim() || null;
    },
    toggleMode() {
      this.isAdvancedMode = !this.isAdvancedMode;
      if (!this.isAdvancedMode) this.sourceId = '';
      this.loadCurrentPrompt();
    },
    async fetchSourceOptions() {
      try {
        const response = await TrafficSourcePromptsAPI.list(this.inbox.id);
        this.sourceOptions = (response.data.payload || []).map(item => ({
          sourceId: item.source_id,
          fileName: item.file_name,
          updatedAt: item.updated_at,
        }));
      } catch (error) {
        useAlert(error?.response?.data?.error || error.message);
      }
    },
    onFileSelect(event) {
      const file = event.target.files?.[0];
      if (!file) return;

      const extension = `.${file.name.split('.').pop()?.toLowerCase()}`;
      if (!ACCEPTED_EXTENSIONS.includes(extension)) {
        useAlert(this.$t('INBOX_MGMT.AI_PROMPTS.ERRORS.UNSUPPORTED_FILE'));
        this.selectedFile = null;
        return;
      }

      this.selectedFile = file;
    },
    async loadCurrentPrompt() {
      this.isLoadingPrompt = true;
      this.currentPrompt = null;
      try {
        const response = await TrafficSourcePromptsAPI.getCurrent(
          this.inbox.id,
          this.normalizedSourceId()
        );
        this.currentPrompt = response.data.payload;
      } catch (error) {
        if (error?.response?.status === 404) {
          this.currentPrompt = null;
          useAlert(this.$t('INBOX_MGMT.AI_PROMPTS.NO_PROMPT'));
        } else {
          useAlert(error?.response?.data?.error || error.message);
        }
      } finally {
        this.isLoadingPrompt = false;
      }
    },
    async uploadPrompt() {
      if (!this.selectedFile) {
        useAlert(this.$t('INBOX_MGMT.AI_PROMPTS.ERRORS.FILE_REQUIRED'));
        return;
      }

      this.isUploading = true;
      try {
        const response = await TrafficSourcePromptsAPI.upload(
          this.inbox.id,
          this.normalizedSourceId(),
          this.selectedFile
        );
        this.currentPrompt = response.data.payload;
        this.selectedFile = null;
        this.$refs.promptFile.value = '';
        useAlert(this.$t('INBOX_MGMT.AI_PROMPTS.UPLOAD_SUCCESS'));
        this.fetchSourceOptions();
      } catch (error) {
        useAlert(error?.response?.data?.error || error.message);
      } finally {
        this.isUploading = false;
      }
    },
    async downloadPrompt() {
      this.isDownloading = true;
      try {
        const response = await TrafficSourcePromptsAPI.download(
          this.inbox.id,
          this.normalizedSourceId()
        );
        const blob = new Blob([response.data], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${this.normalizedSourceId() || 'inbox-default'}-prompt.txt`;
        link.click();
        URL.revokeObjectURL(url);
      } catch (error) {
        useAlert(error?.response?.data?.error || error.message);
      } finally {
        this.isDownloading = false;
      }
    },
    async deletePrompt() {
      this.isDeleting = true;
      try {
        await TrafficSourcePromptsAPI.remove(this.inbox.id, this.normalizedSourceId());
        this.currentPrompt = null;
        useAlert(this.$t('INBOX_MGMT.AI_PROMPTS.DELETE_SUCCESS'));
        this.fetchSourceOptions();
      } catch (error) {
        useAlert(error?.response?.data?.error || error.message);
      } finally {
        this.isDeleting = false;
      }
    },
    selectSource(sourceId) {
      this.sourceId = sourceId;
      this.loadCurrentPrompt();
    },
    formatDate(value) {
      if (!value) return '-';
      return new Date(value).toLocaleString();
    },
  },
};
</script>

<template>
  <div class="max-w-4xl mx-6 flex flex-col gap-6">
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.AI_PROMPTS.MODE_LABEL')"
      :help-text="$t('INBOX_MGMT.AI_PROMPTS.MODE_HELP')"
    >
      <div class="flex gap-2">
        <NextButton
          sm
          ghost
          :label="isAdvancedMode ? $t('INBOX_MGMT.AI_PROMPTS.SWITCH_BASIC') : $t('INBOX_MGMT.AI_PROMPTS.SWITCH_ADVANCED')"
          @click="toggleMode"
        />
      </div>
    </SettingsFieldSection>

    <SettingsFieldSection
      v-if="isAdvancedMode"
      :label="$t('INBOX_MGMT.AI_PROMPTS.SOURCE_ID_LABEL')"
      :help-text="$t('INBOX_MGMT.AI_PROMPTS.SOURCE_ID_HELP')"
    >
      <woot-input v-model="sourceId" class="[&>input]:!mb-0" />
      <div class="flex gap-2 mt-3">
        <NextButton sm :label="$t('INBOX_MGMT.AI_PROMPTS.LOAD')" @click="loadCurrentPrompt" />
      </div>
    </SettingsFieldSection>

    <SettingsFieldSection :label="$t('INBOX_MGMT.AI_PROMPTS.UPLOAD_LABEL')">
      <input
        ref="promptFile"
        type="file"
        class="!mb-0"
        accept=".txt,.doc,.docx,.pdf"
        @change="onFileSelect"
      />
      <p class="text-body-para text-n-slate-11 mt-2 mb-0">
        {{ $t('INBOX_MGMT.AI_PROMPTS.UPLOAD_HELP') }}
      </p>
      <div class="flex gap-2 mt-3">
        <NextButton
          sm
          :is-loading="isUploading"
          :label="$t('INBOX_MGMT.AI_PROMPTS.UPLOAD_ACTION')"
          @click="uploadPrompt"
        />
        <NextButton
          sm
          ghost
          :is-loading="isDownloading"
          :label="$t('INBOX_MGMT.AI_PROMPTS.DOWNLOAD_ACTION')"
          @click="downloadPrompt"
        />
        <NextButton
          sm
          ghost
          class="!text-ruby-09"
          :is-loading="isDeleting"
          :label="$t('INBOX_MGMT.AI_PROMPTS.DELETE_ACTION')"
          @click="deletePrompt"
        />
      </div>
    </SettingsFieldSection>

    <div class="rounded-xl outline -outline-offset-1 outline-1 outline-n-weak p-4 bg-n-surface-1">
      <p class="text-heading-3 mb-2">
        {{ $t('INBOX_MGMT.AI_PROMPTS.STATUS_TITLE') }}
      </p>
      <template v-if="isLoadingPrompt">
        <p class="text-body-para mb-0">{{ $t('INBOX_MGMT.AI_PROMPTS.LOADING') }}</p>
      </template>
      <template v-else-if="currentPrompt">
        <p class="text-body-para mb-1">
          {{ $t('INBOX_MGMT.AI_PROMPTS.FILE_NAME') }}: {{ currentPrompt.file_name }}
        </p>
        <p class="text-body-para mb-0">
          {{ $t('INBOX_MGMT.AI_PROMPTS.UPDATED_AT') }}:
          {{ formatDate(currentPrompt.updated_at) }}
        </p>
      </template>
      <template v-else>
        <p class="text-body-para mb-0">{{ $t('INBOX_MGMT.AI_PROMPTS.NO_PROMPT') }}</p>
      </template>
    </div>

    <div v-if="sourceOptions.length" class="rounded-xl outline -outline-offset-1 outline-1 outline-n-weak p-4 bg-n-surface-1">
      <p class="text-heading-3 mb-2">{{ $t('INBOX_MGMT.AI_PROMPTS.KNOWN_SOURCES') }}</p>
      <div class="flex flex-col gap-2">
        <button
          v-for="item in sourceOptions"
          :key="item.sourceId"
          type="button"
          class="text-left px-3 py-2 rounded-lg bg-n-alpha-1 hover:bg-n-alpha-2 transition-colors"
          @click="selectSource(item.sourceId)"
        >
          <span class="font-medium">{{ displaySourceLabel(item.sourceId) }}</span>
          <span class="text-n-slate-11 ml-2">({{ item.fileName }}, {{ formatDate(item.updatedAt) }})</span>
        </button>
      </div>
    </div>
  </div>
</template>
