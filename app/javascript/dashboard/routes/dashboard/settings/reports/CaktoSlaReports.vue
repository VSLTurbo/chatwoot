<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import subDays from 'date-fns/subDays';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';

import ReportHeader from './components/ReportHeader.vue';
import ReportMetricCard from './components/ReportMetricCard.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const dateRange = ref([subDays(new Date(), 6), new Date()]);
const rangeType = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const inboxId = ref('');

const report = computed(() => getters['caktoSla/getReport'].value);
const uiFlags = computed(() => getters['caktoSla/getUIFlags'].value);
const inboxes = computed(() => getters['inboxes/getInboxes'].value);

const fetchReport = async () => {
  try {
    await store.dispatch('caktoSla/fetchReport', {
      since: getUnixStartOfDay(dateRange.value[0]),
      until: getUnixEndOfDay(dateRange.value[1]),
      inbox_id: inboxId.value || undefined,
    });
  } catch {
    useAlert(t('CAKTO_SLA.REPORT.FETCH_ERROR'));
  }
};

const onDateRangeChange = ([start, end]) => {
  dateRange.value = [start, end];
  fetchReport();
};

watch(inboxId, fetchReport);
onMounted(fetchReport);

const percent = ({ met = 0, measured = 0 } = {}) =>
  measured ? Math.round((met / measured) * 100) : 0;

const ratio = fase =>
  t('CAKTO_SLA.REPORT.RATIO', {
    met: fase?.met || 0,
    measured: fase?.measured || 0,
    percent: percent(fase),
  });

const totals = computed(() => report.value?.totals);
const breached = computed(
  () =>
    (totals.value?.first_response?.breached || 0) +
    (totals.value?.resolution?.breached || 0)
);

const cards = computed(() => [
  {
    label: t('CAKTO_SLA.REPORT.TOTALS.CONVERSATIONS'),
    info: t('CAKTO_SLA.REPORT.TOTALS.CONVERSATIONS_INFO'),
    value: String(totals.value?.conversations || 0),
  },
  {
    label: t('CAKTO_SLA.REPORT.TOTALS.FIRST_RESPONSE'),
    info: t('CAKTO_SLA.REPORT.TOTALS.FIRST_RESPONSE_INFO'),
    value: `${percent(totals.value?.first_response)}%`,
  },
  {
    label: t('CAKTO_SLA.REPORT.TOTALS.RESOLUTION'),
    info: t('CAKTO_SLA.REPORT.TOTALS.RESOLUTION_INFO'),
    value: `${percent(totals.value?.resolution)}%`,
  },
  {
    label: t('CAKTO_SLA.REPORT.TOTALS.BREACHED'),
    info: t('CAKTO_SLA.REPORT.TOTALS.BREACHED_INFO'),
    value: String(breached.value),
  },
]);

const tableHeaders = firstColumn => [
  firstColumn,
  t('CAKTO_SLA.REPORT.TABLE.CONVERSATIONS'),
  t('CAKTO_SLA.REPORT.TABLE.FIRST_RESPONSE'),
  t('CAKTO_SLA.REPORT.TABLE.RESOLUTION'),
  t('CAKTO_SLA.REPORT.TABLE.PENDING'),
];

const pending = row =>
  (row.first_response?.pending || 0) + (row.resolution?.pending || 0);
</script>

<template>
  <ReportHeader
    :header-title="$t('CAKTO_SLA.REPORT.HEADER')"
    :header-description="$t('CAKTO_SLA.REPORT.DESCRIPTION')"
  />
  <div class="flex flex-col gap-6">
    <div class="flex flex-col w-full gap-3 lg:flex-row">
      <WootDatePicker
        v-model:date-range="dateRange"
        v-model:range-type="rangeType"
        @date-range-changed="onDateRangeChange"
      />
      <select
        v-model="inboxId"
        v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_INBOX_FILTER')"
        class="!mb-0 h-10 max-w-xs text-sm rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-12"
      >
        <option value="">{{ $t('CAKTO_SLA.REPORT.ALL_INBOXES') }}</option>
        <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
          {{ inbox.name }}
        </option>
      </select>
    </div>

    <div
      class="grid grid-cols-2 gap-6 p-4 border rounded-xl md:grid-cols-4 border-n-weak bg-n-solid-2"
    >
      <ReportMetricCard
        v-for="card in cards"
        :key="card.label"
        :label="card.label"
        :value="card.value"
        :info-text="card.info"
        :disabled="uiFlags.isFetchingReport"
      />
    </div>

    <section class="flex flex-col gap-2">
      <h3 class="text-heading-3 text-n-slate-12">
        {{ $t('CAKTO_SLA.REPORT.BY_INBOX') }}
      </h3>
      <BaseTable
        :headers="tableHeaders($t('CAKTO_SLA.REPORT.TABLE.INBOX'))"
        :items="report?.by_inbox || []"
        :loading="uiFlags.isFetchingReport"
        :no-data-message="$t('CAKTO_SLA.REPORT.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="row in items" :key="row.inbox_id" :item="row">
            <BaseTableCell>
              <span class="text-body-main text-n-slate-12">
                {{ row.inbox_name }}
              </span>
            </BaseTableCell>
            <BaseTableCell>{{ row.conversations }}</BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_FIRST_RESPONSE')"
            >
              {{ ratio(row.first_response) }}
            </BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_RESOLUTION')"
            >
              {{ ratio(row.resolution) }}
            </BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_PENDING')"
            >
              {{ pending(row) }}
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </section>

    <section class="flex flex-col gap-2">
      <h3 class="text-heading-3 text-n-slate-12">
        {{ $t('CAKTO_SLA.REPORT.BY_AGENT') }}
      </h3>
      <BaseTable
        :headers="tableHeaders($t('CAKTO_SLA.REPORT.TABLE.AGENT'))"
        :items="report?.by_agent || []"
        :loading="uiFlags.isFetchingReport"
        :no-data-message="$t('CAKTO_SLA.REPORT.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="row in items"
            :key="row.assignee_id || 'sem'"
            :item="row"
          >
            <BaseTableCell>
              <span class="text-body-main text-n-slate-12">
                {{ row.name || $t('CAKTO_SLA.REPORT.UNASSIGNED') }}
              </span>
            </BaseTableCell>
            <BaseTableCell>{{ row.conversations }}</BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_FIRST_RESPONSE')"
            >
              {{ ratio(row.first_response) }}
            </BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_RESOLUTION')"
            >
              {{ ratio(row.resolution) }}
            </BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_PENDING')"
            >
              {{ pending(row) }}
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </section>

    <section class="flex flex-col gap-2">
      <h3 class="text-heading-3 text-n-slate-12">
        {{ $t('CAKTO_SLA.REPORT.BY_TEAM') }}
      </h3>
      <BaseTable
        :headers="tableHeaders($t('CAKTO_SLA.REPORT.TABLE.TEAM'))"
        :items="report?.by_team || []"
        :loading="uiFlags.isFetchingReport"
        :no-data-message="$t('CAKTO_SLA.REPORT.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="row in items" :key="row.team_id" :item="row">
            <BaseTableCell>
              <span class="text-body-main text-n-slate-12">
                {{ row.team_name }}
              </span>
            </BaseTableCell>
            <BaseTableCell>{{ row.conversations }}</BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_FIRST_RESPONSE')"
            >
              {{ ratio(row.first_response) }}
            </BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_RESOLUTION')"
            >
              {{ ratio(row.resolution) }}
            </BaseTableCell>
            <BaseTableCell
              v-tooltip.top="$t('TOOLTIPS.CAKTO_SLA.REPORT_PENDING')"
            >
              {{ pending(row) }}
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </section>
  </div>
</template>
