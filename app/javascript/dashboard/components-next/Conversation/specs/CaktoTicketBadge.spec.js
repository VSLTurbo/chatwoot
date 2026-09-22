import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import CaktoTicketBadge from '../CaktoTicketBadge.vue';
import ptBR from 'dashboard/i18n/locale/pt_BR/caktoTickets.json';

describe('CaktoTicketBadge', () => {
  it('mostra o selo traduzido', () => {
    const wrapper = mount(CaktoTicketBadge, {
      global: {
        plugins: [
          createI18n({
            legacy: false,
            locale: 'pt_BR',
            messages: { pt_BR: ptBR },
          }),
        ],
      },
    });
    expect(wrapper.text()).toBe('Ticket interno');
    expect(wrapper.find('.i-lucide-ticket').exists()).toBe(true);
  });
});
