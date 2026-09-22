// Estado do selo de SLA da Cakto, calculado no cliente a partir de
// `conversation.cakto_sla` (vencimentos e status em unix segundos).
// Devolve null quando não há SLA; senão { fase, tom, chave, tempo }.
//   fase:  primeira_resposta | resolucao | estourado | cumprido
//   tom:   verde | ambar | vermelho
//   chave: sufixo de CAKTO_SLA.BADGE para o texto; tempo: "1h 20m"

const LIMIAR_AMBAR = 0.2;

export const formatarDuracao = segundos => {
  const minutos = Math.max(1, Math.floor(Math.abs(segundos) / 60));
  const dias = Math.floor(minutos / 1440);
  const horas = Math.floor((minutos % 1440) / 60);
  const min = minutos % 60;
  if (dias) return horas ? `${dias}d ${horas}h` : `${dias}d`;
  if (horas) return min ? `${horas}h ${min}m` : `${horas}h`;
  return `${min}m`;
};

const faseAberta = (status, vencimento, concluidaEm) =>
  status === 'pending' && vencimento && !concluidaEm;

const contagem = (fase, vencimento, createdAt, now) => {
  const restante = vencimento - now;
  const tempo = formatarDuracao(restante);
  if (restante < 0) {
    return { fase, tom: 'vermelho', chave: `${fase}_ATRASADA`, tempo };
  }
  const total = createdAt ? vencimento - createdAt : 0;
  const tom = total && restante < total * LIMIAR_AMBAR ? 'ambar' : 'verde';
  return { fase, tom, chave: `${fase}_EM`, tempo };
};

export const caktoSlaStatus = (
  sla,
  { firstReplyCreatedAt, status, createdAt, now = Date.now() / 1000 } = {}
) => {
  if (!sla) return null;

  const {
    first_response_status: fr,
    resolution_status: rs,
    first_response_due_at: frDue,
    resolution_due_at: rsDue,
  } = sla;

  if (faseAberta(fr, frDue, firstReplyCreatedAt)) {
    return contagem('primeira_resposta', frDue, createdAt, now);
  }
  const resolvida = status === 'resolved';
  if (faseAberta(rs, rsDue, resolvida)) {
    return contagem('resolucao', rsDue, createdAt, now);
  }

  // Nenhuma fase aberta: só resta dizer se cumpriu ou estourou. Fase ainda
  // `pending` no servidor (job de 5 min não passou) é julgada aqui pelo prazo.
  const estourou =
    fr === 'breached' ||
    rs === 'breached' ||
    (fr === 'pending' && frDue && firstReplyCreatedAt > frDue) ||
    (rs === 'pending' && rsDue && now > rsDue);
  return estourou
    ? { fase: 'estourado', tom: 'vermelho', chave: 'ESTOURADO', tempo: '' }
    : { fase: 'cumprido', tom: 'verde', chave: 'CUMPRIDO', tempo: '' };
};
