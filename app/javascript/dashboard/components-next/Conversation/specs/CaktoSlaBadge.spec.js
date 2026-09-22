import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import CaktoSlaBadge from '../CaktoSlaBadge.vue';
import ptBR from 'dashboard/i18n/locale/pt_BR/caktoSla.json';

const criada = 1_790_000_000;
const chat = {
  status: 'open',
  created_at: criada,
  first_reply_created_at: 0,
  cakto_sla: {
    policy_id: 1,
    policy_name: 'Suporte padrão',
    first_response_due_at: criada + 30 * 60,
    resolution_due_at: criada + 8 * 3600,
    first_response_status: 'pending',
    resolution_status: 'pending',
    breached_at: null,
  },
};

const montar = props =>
  mount(CaktoSlaBadge, {
    props,
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: ptBR },
        }),
      ],
      directives: { tooltip: {} },
    },
  });

describe('CaktoSlaBadge', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date((criada + 10 * 60) * 1000));
  });
  afterEach(() => vi.useRealTimers());

  it('não renderiza sem SLA', () => {
    expect(montar({ chat: { ...chat, cakto_sla: null } }).html()).toBe(
      '<!--v-if-->'
    );
  });

  it('mostra o tempo restante e atualiza sozinho a cada 30 s', async () => {
    const wrapper = montar({ chat });
    expect(wrapper.text()).toBe('Responder em 20m');
    expect(wrapper.classes()).toContain('text-n-teal-11');

    vi.setSystemTime(new Date((criada + 35 * 60) * 1000));
    await vi.advanceTimersByTimeAsync(30_000);
    await nextTick();
    expect(wrapper.text()).toBe('Resposta atrasada há 5m');
    expect(wrapper.classes()).toContain('text-n-ruby-11');
  });
});
