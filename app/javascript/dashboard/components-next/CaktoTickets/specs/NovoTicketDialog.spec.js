import { flushPromises, mount } from '@vue/test-utils';
import { nextTick, ref } from 'vue';
import NovoTicketDialog from '../NovoTicketDialog.vue';

const dispatch = vi.fn();
const push = vi.fn();
const useAlert = vi.fn();
const teams = ref([]);

vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => useAlert(...args),
}));
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useStoreGetters: () => ({
    'caktoTickets/getTeams': teams,
    'caktoTickets/getUIFlags': ref({ isCreating: false }),
  }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const DialogStub = {
  name: 'Dialog',
  emits: ['close', 'confirm'],
  methods: { open() {}, close() {} },
  template: `<section><slot /><button data-test="confirm" @click="$emit('confirm')" /></section>`,
};

const montar = async props => {
  const wrapper = mount(NovoTicketDialog, {
    props,
    global: { stubs: { Dialog: DialogStub }, mocks: { $t: key => key } },
  });
  await wrapper.vm.open();
  await flushPromises();
  return wrapper;
};

describe('NovoTicketDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    teams.value = [{ id: 2, name: 'Compliance' }];
    dispatch.mockImplementation(async action =>
      action === 'caktoTickets/create' ? { id: 321 } : undefined
    );
  });

  it('busca o setup ao abrir só quando ainda não tem equipes', async () => {
    teams.value = [];
    await montar();
    expect(dispatch).toHaveBeenCalledWith('caktoTickets/fetchSetup');
    dispatch.mockClear();
    teams.value = [{ id: 2, name: 'Compliance' }];
    await montar();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it('não envia e mostra os erros com os campos obrigatórios vazios', async () => {
    const wrapper = await montar();
    await wrapper.find('[data-test="confirm"]').trigger('click');
    await nextTick();
    expect(dispatch).not.toHaveBeenCalledWith(
      'caktoTickets/create',
      expect.anything()
    );
    expect(wrapper.text()).toContain('CAKTO_TICKETS.FORM.ERRORS.TEAM');
    expect(wrapper.text()).toContain('CAKTO_TICKETS.FORM.ERRORS.TITLE');
    expect(wrapper.text()).toContain('CAKTO_TICKETS.FORM.ERRORS.DESCRIPTION');
  });

  it('cria, avisa e navega para a conversa', async () => {
    const wrapper = await montar({ relatedConversationId: 55 });
    await wrapper.find('[data-test="team"]').setValue(2);
    await wrapper.find('[data-test="title"] input').setValue(' Estorno ');
    await wrapper
      .find('[data-test="description"] textarea')
      .setValue('Seller pediu estorno');
    await wrapper.find('[data-test="priority"]').setValue('high');
    await wrapper.find('[data-test="confirm"]').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('caktoTickets/create', {
      team_id: 2,
      title: 'Estorno',
      description: 'Seller pediu estorno',
      priority: 'high',
      seller: undefined,
      related_conversation_display_id: 55,
    });
    expect(useAlert).toHaveBeenCalledWith('CAKTO_TICKETS.FORM.SUCCESS');
    expect(push).toHaveBeenCalledWith({
      name: 'inbox_conversation',
      params: { conversation_id: 321 },
    });
  });

  it('mostra a mensagem do 422 e não navega', async () => {
    dispatch.mockImplementation(async action => {
      if (action === 'caktoTickets/create')
        throw new Error('Conversa relacionada não existe');
      return undefined;
    });
    const wrapper = await montar();
    await wrapper.find('[data-test="team"]').setValue(2);
    await wrapper.find('[data-test="title"] input').setValue('x');
    await wrapper.find('[data-test="description"] textarea').setValue('y');
    await wrapper.find('[data-test="confirm"]').trigger('click');
    await flushPromises();
    expect(useAlert).toHaveBeenCalledWith('Conversa relacionada não existe');
    expect(push).not.toHaveBeenCalled();
  });
});
