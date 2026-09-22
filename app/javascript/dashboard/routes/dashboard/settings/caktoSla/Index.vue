<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { picoSearch } from '@chatwoot/pico-search';

import PolicyForm from './PolicyForm.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const searchQuery = ref('');
const showForm = ref(false);
const showDelete = ref(false);
const selected = ref(null);

const records = computed(() => getters['caktoSla/getPolicies'].value);
const uiFlags = computed(() => getters['caktoSla/getUIFlags'].value);

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  return picoSearch(records.value, query, ['name', 'description']);
});

const tableHeaders = computed(() => [
  t('CAKTO_SLA.SETTINGS.LIST.TABLE_HEADER.NAME'),
  t('CAKTO_SLA.SETTINGS.LIST.TABLE_HEADER.FIRST_RESPONSE'),
  t('CAKTO_SLA.SETTINGS.LIST.TABLE_HEADER.RESOLUTION'),
  t('CAKTO_SLA.SETTINGS.LIST.TABLE_HEADER.INBOXES'),
  t('CAKTO_SLA.SETTINGS.LIST.TABLE_HEADER.STATUS'),
  t('CAKTO_SLA.SETTINGS.LIST.TABLE_HEADER.ACTION'),
]);

const minutos = valor =>
  valor ? `${valor} min` : t('CAKTO_SLA.SETTINGS.LIST.NOT_MEASURED');

const openForm = policy => {
  selected.value = policy;
  showForm.value = true;
};
const closeForm = () => {
  showForm.value = false;
};

const openDelete = policy => {
  selected.value = policy;
  showDelete.value = true;
};
const closeDelete = () => {
  showDelete.value = false;
};

const confirmDelete = async () => {
  closeDelete();
  try {
    await store.dispatch('caktoSla/delete', selected.value.id);
    useAlert(t('CAKTO_SLA.SETTINGS.API.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(error?.message || t('CAKTO_SLA.SETTINGS.API.ERROR'));
  }
};

onBeforeMount(() => {
  store.dispatch('caktoSla/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('CAKTO_SLA.SETTINGS.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('CAKTO_SLA.SETTINGS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('CAKTO_SLA.SETTINGS.HEADER')"
        :description="$t('CAKTO_SLA.SETTINGS.DESCRIPTION')"
        :search-placeholder="$t('CAKTO_SLA.SETTINGS.SEARCH_PLACEHOLDER')"
        feature-name="cakto_sla"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('CAKTO_SLA.SETTINGS.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('CAKTO_SLA.SETTINGS.HEADER_BTN_TXT')"
            size="sm"
            @click="openForm(null)"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery
            ? $t('CAKTO_SLA.SETTINGS.NO_RESULTS')
            : $t('CAKTO_SLA.SETTINGS.LIST.404')
        "
      >
        <template #row="{ items }">
          <BaseTableRow v-for="policy in items" :key="policy.id" :item="policy">
            <BaseTableCell>
              <span class="text-body-main text-n-slate-12">
                {{ policy.name }}
              </span>
              <p v-if="policy.description" class="mb-0 text-sm text-n-slate-11">
                {{ policy.description }}
              </p>
            </BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.FIRST_RESPONSE')"
            >
              <span class="text-body-main text-n-slate-11">
                {{ minutos(policy.first_response_minutes) }}
              </span>
            </BaseTableCell>
            <BaseTableCell v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.RESOLUTION')">
              <span class="text-body-main text-n-slate-11">
                {{ minutos(policy.resolution_minutes) }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-body-main text-n-slate-11">
                {{
                  $t('CAKTO_SLA.SETTINGS.LIST.INBOX_COUNT', {
                    n: policy.inbox_ids?.length || 0,
                  })
                }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <span
                v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.ACTIVE')"
                class="px-2 py-0.5 text-xs font-medium rounded-md"
                :class="
                  policy.active
                    ? 'text-n-teal-11 bg-n-teal-3'
                    : 'text-n-slate-11 bg-n-slate-3'
                "
              >
                {{
                  policy.active
                    ? $t('CAKTO_SLA.SETTINGS.LIST.ACTIVE')
                    : $t('CAKTO_SLA.SETTINGS.LIST.INACTIVE')
                }}
              </span>
            </BaseTableCell>
            <BaseTableCell align="end">
              <div class="flex justify-end gap-3 flex-shrink-0">
                <Button
                  v-tooltip.top="$t('CAKTO_SLA.SETTINGS.FORM.EDIT')"
                  icon="i-woot-edit-pen"
                  slate
                  sm
                  @click="openForm(policy)"
                />
                <Button
                  v-tooltip.top="$t('CAKTO_SLA.SETTINGS.FORM.DELETE')"
                  icon="i-woot-bin"
                  slate
                  sm
                  class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                  :is-loading="uiFlags.isDeleting"
                  @click="openDelete(policy)"
                />
              </div>
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showForm" :on-close="closeForm">
      <PolicyForm
        v-if="showForm"
        :key="selected?.id || 'nova'"
        :policy="selected"
        @close="closeForm"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDelete"
      :on-close="closeDelete"
      :on-confirm="confirmDelete"
      :title="$t('CAKTO_SLA.SETTINGS.DELETE.TITLE')"
      :message="$t('CAKTO_SLA.SETTINGS.DELETE.MESSAGE')"
      :message-value="` ${selected?.name}?`"
      :confirm-text="$t('CAKTO_SLA.SETTINGS.DELETE.YES')"
      :reject-text="$t('CAKTO_SLA.SETTINGS.DELETE.NO')"
    />
  </SettingsLayout>
</template>
