<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  // display_id da conversa de cliente que origina o ticket (cabeçalho).
  relatedConversationId: {
    type: [Number, String],
    default: null,
  },
});

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const getters = useStoreGetters();

const dialogRef = ref(null);
const teamId = ref('');
const title = ref('');
const description = ref('');
const priority = ref('medium');
const seller = ref('');
const related = ref('');
const submitted = ref(false);

const PRIORITIES = computed(() => [
  { value: 'low', label: t('CAKTO_TICKETS.FORM.PRIORITY.LOW') },
  { value: 'medium', label: t('CAKTO_TICKETS.FORM.PRIORITY.MEDIUM') },
  { value: 'high', label: t('CAKTO_TICKETS.FORM.PRIORITY.HIGH') },
  { value: 'urgent', label: t('CAKTO_TICKETS.FORM.PRIORITY.URGENT') },
]);
const SELECT_CLASS =
  '!mb-0 h-10 w-full text-sm rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-12';

const teams = computed(() => getters['caktoTickets/getTeams'].value);
const uiFlags = computed(() => getters['caktoTickets/getUIFlags'].value);

const errors = computed(() => ({
  team: !teamId.value ? t('CAKTO_TICKETS.FORM.ERRORS.TEAM') : '',
  title: !title.value.trim() ? t('CAKTO_TICKETS.FORM.ERRORS.TITLE') : '',
  description: !description.value.trim()
    ? t('CAKTO_TICKETS.FORM.ERRORS.DESCRIPTION')
    : '',
}));
const isValid = computed(() => !Object.values(errors.value).some(Boolean));
const erro = campo => (submitted.value ? errors.value[campo] : '');

const open = async () => {
  teamId.value = '';
  title.value = '';
  description.value = '';
  priority.value = 'medium';
  seller.value = '';
  related.value = props.relatedConversationId ?? '';
  submitted.value = false;
  dialogRef.value?.open();
  if (!teams.value.length) {
    try {
      await store.dispatch('caktoTickets/fetchSetup');
    } catch {
      useAlert(t('CAKTO_TICKETS.FORM.SETUP_ERROR'));
    }
  }
};

const submit = async () => {
  submitted.value = true;
  if (!isValid.value) return;
  try {
    const data = await store.dispatch('caktoTickets/create', {
      team_id: Number(teamId.value),
      title: title.value.trim(),
      description: description.value.trim(),
      priority: priority.value,
      seller: seller.value.trim() || undefined,
      related_conversation_display_id: related.value
        ? Number(related.value)
        : undefined,
    });
    dialogRef.value?.close();
    useAlert(t('CAKTO_TICKETS.FORM.SUCCESS'));
    router.push({
      name: 'inbox_conversation',
      params: { conversation_id: data.id },
    });
  } catch (error) {
    useAlert(error?.message || t('CAKTO_TICKETS.FORM.ERROR'));
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('CAKTO_TICKETS.FORM.TITLE')"
    :description="$t('CAKTO_TICKETS.FORM.DESCRIPTION')"
    :cancel-button-label="$t('CAKTO_TICKETS.FORM.CANCEL')"
    :confirm-button-label="$t('CAKTO_TICKETS.FORM.SUBMIT')"
    :is-loading="uiFlags.isCreating"
    overflow-y-auto
    @confirm="submit"
  >
    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('CAKTO_TICKETS.FORM.TEAM.LABEL') }}
        </label>
        <select
          v-model="teamId"
          v-tooltip.top="$t('TOOLTIPS.CAKTO_TICKETS.TEAM')"
          data-test="team"
          :class="SELECT_CLASS"
          :disabled="uiFlags.isFetchingSetup"
        >
          <option value="" disabled>
            {{ $t('CAKTO_TICKETS.FORM.TEAM.PLACEHOLDER') }}
          </option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
        <p v-if="erro('team')" class="mb-0 text-xs text-n-ruby-9">
          {{ erro('team') }}
        </p>
      </div>
      <Input
        v-model="title"
        data-test="title"
        :label="$t('CAKTO_TICKETS.FORM.TICKET_TITLE.LABEL')"
        :placeholder="$t('CAKTO_TICKETS.FORM.TICKET_TITLE.PLACEHOLDER')"
        :message="erro('title')"
        :message-type="erro('title') ? 'error' : 'info'"
      />
      <TextArea
        v-model="description"
        data-test="description"
        :label="$t('CAKTO_TICKETS.FORM.TICKET_DESCRIPTION.LABEL')"
        :placeholder="$t('CAKTO_TICKETS.FORM.TICKET_DESCRIPTION.PLACEHOLDER')"
        :message="erro('description')"
        :message-type="erro('description') ? 'error' : 'info'"
        auto-height
      />
      <div class="grid grid-cols-2 gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('CAKTO_TICKETS.FORM.PRIORITY.LABEL') }}
          </label>
          <select
            v-model="priority"
            v-tooltip.top="$t('TOOLTIPS.CAKTO_TICKETS.PRIORITY')"
            data-test="priority"
            :class="SELECT_CLASS"
          >
            <option v-for="p in PRIORITIES" :key="p.value" :value="p.value">
              {{ p.label }}
            </option>
          </select>
        </div>
        <Input
          v-model="related"
          v-tooltip.top="$t('TOOLTIPS.CAKTO_TICKETS.RELATED')"
          data-test="related"
          type="number"
          min="1"
          :label="$t('CAKTO_TICKETS.FORM.RELATED.LABEL')"
          :placeholder="$t('CAKTO_TICKETS.FORM.RELATED.PLACEHOLDER')"
        />
      </div>
      <Input
        v-model="seller"
        v-tooltip.top="$t('TOOLTIPS.CAKTO_TICKETS.SELLER')"
        data-test="seller"
        :label="$t('CAKTO_TICKETS.FORM.SELLER.LABEL')"
        :placeholder="$t('CAKTO_TICKETS.FORM.SELLER.PLACEHOLDER')"
      />
    </div>
  </Dialog>
</template>
