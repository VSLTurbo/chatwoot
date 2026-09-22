<template>
  <span
    v-tooltip.top="$t('TOOLTIPS.CONVERSATION.CAKTO_TICKET_BADGE')"
    class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-xs font-medium whitespace-nowrap flex-shrink-0 text-n-iris-11 bg-n-iris-3"
  >
    <span class="i-lucide-ticket size-3 flex-shrink-0" />
    {{ $t('CAKTO_TICKETS.BADGE') }}
  </span>
</template>
