<script setup>
import { computed } from 'vue';
import { useNow } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { caktoSlaStatus } from 'dashboard/helper/caktoSlaStatus';

// `chat` no formato da API (snake_case): cakto_sla, first_reply_created_at,
// status, created_at.
const props = defineProps({
  chat: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const now = useNow({ interval: 30_000 });

const estado = computed(() =>
  caktoSlaStatus(props.chat.cakto_sla, {
    firstReplyCreatedAt: props.chat.first_reply_created_at,
    status: props.chat.status,
    createdAt: props.chat.created_at,
    now: now.value.getTime() / 1000,
  })
);

const TONS = {
  verde: 'text-n-teal-11 bg-n-teal-3',
  ambar: 'text-n-amber-11 bg-n-amber-3',
  vermelho: 'text-n-ruby-11 bg-n-ruby-3',
};
</script>

<template>
  <span
    v-if="estado"
    v-tooltip.top="chat.cakto_sla.policy_name"
    class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-xs font-medium whitespace-nowrap flex-shrink-0"
    :class="TONS[estado.tom]"
  >
    <span class="i-lucide-timer size-3 flex-shrink-0" />
    {{ t(`CAKTO_SLA.BADGE.${estado.chave}`, { tempo: estado.tempo }) }}
  </span>
</template>
