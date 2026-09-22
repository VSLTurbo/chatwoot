<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
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
// Relógio próprio (segundos unix) atualizado a cada 30 s. Não usa useNow do
// vueuse: no vitest ele resolve outra cópia do Vue e o computed não reage.
const now = ref(Date.now() / 1000);
let relogio;
onMounted(() => {
  relogio = setInterval(() => {
    now.value = Date.now() / 1000;
  }, 30_000);
});
onUnmounted(() => clearInterval(relogio));

const estado = computed(() =>
  caktoSlaStatus(props.chat.cakto_sla, {
    firstReplyCreatedAt: props.chat.first_reply_created_at,
    status: props.chat.status,
    createdAt: props.chat.created_at,
    now: now.value,
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
    v-tooltip.top="
      `${chat.cakto_sla.policy_name}. ${t(`TOOLTIPS.CONVERSATION.CAKTO_SLA.${estado.fase}`)}`
    "
    class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-xs font-medium whitespace-nowrap flex-shrink-0"
    :class="TONS[estado.tom]"
  >
    <span class="i-lucide-timer size-3 flex-shrink-0" />
    {{ t(`CAKTO_SLA.BADGE.${estado.chave}`, { tempo: estado.tempo }) }}
  </span>
</template>
