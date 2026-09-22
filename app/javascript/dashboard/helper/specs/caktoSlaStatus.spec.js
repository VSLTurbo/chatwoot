import { caktoSlaStatus, formatarDuracao } from '../caktoSlaStatus';

const criada = 1_790_000_000;
const now = criada + 10 * 60; // 10 min depois de criar
const base = {
  policy_id: 1,
  policy_name: 'Suporte padrão',
  first_response_due_at: criada + 30 * 60, // 30 min
  resolution_due_at: criada + 8 * 3600, // 8 h
  first_response_status: 'pending',
  resolution_status: 'pending',
  breached_at: null,
};
const opts = extra => ({ status: 'open', createdAt: criada, now, ...extra });

describe('formatarDuracao', () => {
  it('formata minutos, horas e dias', () => {
    expect(formatarDuracao(30)).toBe('1m');
    expect(formatarDuracao(12 * 60)).toBe('12m');
    expect(formatarDuracao(80 * 60)).toBe('1h 20m');
    expect(formatarDuracao(2 * 3600)).toBe('2h');
    expect(formatarDuracao(-26 * 3600)).toBe('1d 2h');
  });
});

describe('caktoSlaStatus', () => {
  it('sem SLA não renderiza nada', () => {
    expect(caktoSlaStatus(null, opts())).toBeNull();
    expect(caktoSlaStatus(undefined)).toBeNull();
  });

  it('primeira resposta pendente: verde com o tempo restante', () => {
    expect(caktoSlaStatus(base, opts())).toEqual({
      fase: 'primeira_resposta',
      tom: 'verde',
      chave: 'primeira_resposta_EM',
      tempo: '20m',
    });
  });

  it('âmbar quando falta menos de 20% do prazo', () => {
    const r = caktoSlaStatus(base, opts({ now: criada + 25 * 60 }));
    expect(r.tom).toBe('ambar');
    expect(r.tempo).toBe('5m');
  });

  it('sem created_at não tem como calcular o âmbar: fica verde', () => {
    const r = caktoSlaStatus(
      base,
      opts({ now: criada + 25 * 60, createdAt: undefined })
    );
    expect(r.tom).toBe('verde');
  });

  it('atrasada: vermelho com o tempo passado', () => {
    expect(caktoSlaStatus(base, opts({ now: criada + 35 * 60 }))).toEqual({
      fase: 'primeira_resposta',
      tom: 'vermelho',
      chave: 'primeira_resposta_ATRASADA',
      tempo: '5m',
    });
  });

  it('primeira resposta dada (servidor ainda pendente): passa para resolução', () => {
    const r = caktoSlaStatus(
      base,
      opts({ firstReplyCreatedAt: criada + 5 * 60 })
    );
    expect(r.fase).toBe('resolucao');
    expect(r.chave).toBe('resolucao_EM');
    expect(r.tempo).toBe('7h 50m');
    expect(r.tom).toBe('verde');
  });

  it('primeira resposta cumprida e resolução atrasada', () => {
    const sla = { ...base, first_response_status: 'met' };
    const r = caktoSlaStatus(sla, opts({ now: criada + 9 * 3600 }));
    expect(r).toEqual({
      fase: 'resolucao',
      tom: 'vermelho',
      chave: 'resolucao_ATRASADA',
      tempo: '1h',
    });
  });

  it('estourado pelo servidor: vermelho', () => {
    const sla = {
      ...base,
      first_response_status: 'breached',
      resolution_status: 'met',
    };
    expect(caktoSlaStatus(sla, opts()).fase).toBe('estourado');
    expect(caktoSlaStatus(sla, opts()).tom).toBe('vermelho');
  });

  it('primeira resposta estourada mas resolução em aberto: mostra a resolução', () => {
    const sla = { ...base, first_response_status: 'breached' };
    expect(caktoSlaStatus(sla, opts()).fase).toBe('resolucao');
  });

  it('cumprido: as duas fases dentro do prazo', () => {
    const sla = {
      ...base,
      first_response_status: 'met',
      resolution_status: 'met',
    };
    expect(caktoSlaStatus(sla, opts())).toEqual({
      fase: 'cumprido',
      tom: 'verde',
      chave: 'CUMPRIDO',
      tempo: '',
    });
  });

  it('resolvida antes do job rodar: julga pelo prazo', () => {
    const sla = { ...base, first_response_status: 'met' };
    const noPrazo = caktoSlaStatus(sla, opts({ status: 'resolved' }));
    expect(noPrazo.fase).toBe('cumprido');
    const tarde = caktoSlaStatus(
      sla,
      opts({ status: 'resolved', now: criada + 9 * 3600 })
    );
    expect(tarde.fase).toBe('estourado');
  });

  it('prazo não medido (nulo) é ignorado', () => {
    const sla = {
      ...base,
      first_response_due_at: null,
      first_response_status: 'not_measured',
    };
    expect(caktoSlaStatus(sla, opts()).fase).toBe('resolucao');
  });
});
