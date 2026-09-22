<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  // null cria; objeto edita
  policy: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const isEdit = computed(() => !!props.policy?.id);

const name = ref(props.policy?.name || '');
const description = ref(props.policy?.description || '');
const firstResponseMinutes = ref(props.policy?.first_response_minutes ?? '');
const resolutionMinutes = ref(props.policy?.resolution_minutes ?? '');
const inboxIds = ref([...(props.policy?.inbox_ids || [])]);
const active = ref(props.policy?.active ?? true);

const uiFlags = computed(() => getters['caktoSla/getUIFlags'].value);
const isSaving = computed(
  () => uiFlags.value.isCreating || uiFlags.value.isUpdating
);

const inboxOptions = computed(() =>
  getters['inboxes/getInboxes'].value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);

// Campo em branco = não medir; senão inteiro positivo.
const minutosOuNulo = valor => {
  if (valor === '' || valor === null) return null;
  const n = Number(valor);
  return Number.isInteger(n) && n > 0 ? n : NaN;
};

const isValid = computed(() => {
  const fr = minutosOuNulo(firstResponseMinutes.value);
  const rs = minutosOuNulo(resolutionMinutes.value);
  return name.value.trim().length > 0 && !Number.isNaN(fr) && !Number.isNaN(rs);
});

const submit = async () => {
  const payload = {
    name: name.value.trim(),
    description: description.value,
    first_response_minutes: minutosOuNulo(firstResponseMinutes.value),
    resolution_minutes: minutosOuNulo(resolutionMinutes.value),
    inbox_ids: inboxIds.value,
    active: active.value,
  };
  try {
    if (isEdit.value) {
      await store.dispatch('caktoSla/update', {
        id: props.policy.id,
        ...payload,
      });
      useAlert(t('CAKTO_SLA.SETTINGS.API.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('caktoSla/create', payload);
      useAlert(t('CAKTO_SLA.SETTINGS.API.CREATE_SUCCESS'));
    }
    emit('close');
  } catch (error) {
    useAlert(error?.message || t('CAKTO_SLA.SETTINGS.API.ERROR'));
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        isEdit
          ? $t('CAKTO_SLA.SETTINGS.FORM.EDIT_TITLE')
          : $t('CAKTO_SLA.SETTINGS.FORM.ADD_TITLE')
      "
      :header-content="$t('CAKTO_SLA.SETTINGS.FORM.HINT')"
    />
    <form class="flex flex-col gap-4 px-8 pt-2 pb-6" @submit.prevent="submit">
      <Input
        v-model="name"
        :label="$t('CAKTO_SLA.SETTINGS.FORM.NAME.LABEL')"
        :placeholder="$t('CAKTO_SLA.SETTINGS.FORM.NAME.PLACEHOLDER')"
        autofocus
      />
      <TextArea
        v-model="description"
        :label="$t('CAKTO_SLA.SETTINGS.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('CAKTO_SLA.SETTINGS.FORM.DESCRIPTION.PLACEHOLDER')"
      />
      <div class="grid grid-cols-2 gap-4">
        <Input
          v-model="firstResponseMinutes"
          v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.FIRST_RESPONSE')"
          type="number"
          min="1"
          :label="$t('CAKTO_SLA.SETTINGS.FORM.FIRST_RESPONSE.LABEL')"
          :placeholder="
            $t('CAKTO_SLA.SETTINGS.FORM.FIRST_RESPONSE.PLACEHOLDER')
          "
        />
        <Input
          v-model="resolutionMinutes"
          v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.RESOLUTION')"
          type="number"
          min="1"
          :label="$t('CAKTO_SLA.SETTINGS.FORM.RESOLUTION.LABEL')"
          :placeholder="$t('CAKTO_SLA.SETTINGS.FORM.RESOLUTION.PLACEHOLDER')"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('CAKTO_SLA.SETTINGS.FORM.INBOXES.LABEL') }}
        </label>
        <TagMultiSelectComboBox
          v-model="inboxIds"
          v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.INBOXES')"
          :options="inboxOptions"
          :placeholder="$t('CAKTO_SLA.SETTINGS.FORM.INBOXES.PLACEHOLDER')"
        />
      </div>
      <label
        v-tooltip.right="$t('TOOLTIPS.CAKTO_SLA.ACTIVE')"
        class="flex items-center gap-2 cursor-pointer"
      >
        <Checkbox v-model="active" />
        <span class="text-sm text-n-slate-12">
          {{ $t('CAKTO_SLA.SETTINGS.FORM.ACTIVE') }}
        </span>
      </label>
      <div class="flex items-center justify-end w-full gap-2 pt-2">
        <NextButton
          faded
          slate
          type="button"
          :label="$t('CAKTO_SLA.SETTINGS.FORM.CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          type="submit"
          :label="
            isEdit
              ? $t('CAKTO_SLA.SETTINGS.FORM.SAVE')
              : $t('CAKTO_SLA.SETTINGS.FORM.CREATE')
          "
          :disabled="!isValid || isSaving"
          :is-loading="isSaving"
        />
      </div>
    </form>
  </div>
</template>
