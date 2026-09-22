# Ticket e SLA da Cakto (código nosso, núcleo MIT)

Decisão do Ítalo (22/09/2026): o SLA do Chatwoot é Enterprise (pasta `enterprise/`,
licença paga). O nosso é escrito do zero no núcleo, com nomes e tabelas próprios,
prefixo `cakto_`. **Ninguém abre nem copia nada de `enterprise/`.**

"Ticket" = conversa do Chatwoot (já tem número `display_id`, status, prioridade,
responsável, etiquetas). O que falta e este módulo entrega: prazo por conversa,
selo visível, marcação de estouro e relatório.

## Regras

- Uma **política** pertence à conta e vale para um conjunto de caixas de entrada
  (`inbox_ids`). Uma caixa aparece em no máximo uma política ativa (validar).
- Dois prazos, em minutos, cada um opcional (nulo = não medir): **primeira
  resposta** e **resolução**. Contagem em tempo corrido a partir de
  `conversation.created_at` (horário comercial fica para depois).
- Ao criar a conversa numa caixa coberta: cria `cakto_conversation_slas` com os
  vencimentos calculados e status `pending` (ou `not_measured` quando o prazo é nulo).
- Primeira resposta de agente (`FIRST_REPLY_CREATED`): se `pending`, vira `met`
  quando `Time.current <= first_response_due_at`, senão `breached`.
- Conversa resolvida (`CONVERSATION_RESOLVED`): idem para resolução.
- Job a cada 5 min: todo `pending` com vencimento passado vira `breached`
  (`breached_at`), recebe a etiqueta `sla-estourado` (criar a `Label` na conta se
  não existir; título "SLA estourado", cor `#E53935`) e uma mensagem de atividade na
  conversa: "SLA de primeira resposta estourado (política X)" / "SLA de resolução
  estourado (política X)". Etiqueta e atividade já disparam `conversation_updated`
  e `message_created` (webhooks/automações/n8n reagem sem evento novo).
- Reabrir conversa: não mexe no SLA (MVP).
- Feature flag `cakto_sla` em `config/features.yml`: **anexada no fim**, com
  `column: feature_flags_ext_1`, `enabled: true`, sem `premium`.

## Tabelas (migration Rails 7.1, `db/migrate/`)

`cakto_sla_policies`
- `account_id` (references, fk cascade, index), `name` string not null,
  `description` text, `first_response_minutes` integer (null ok),
  `resolution_minutes` integer (null ok), `inbox_ids` integer array default `[]`,
  `active` boolean default true, timestamps.

`cakto_conversation_slas`
- `account_id` (fk cascade), `conversation_id` (fk cascade, **unique**),
  `cakto_sla_policy_id` (fk cascade), `first_response_due_at` datetime,
  `resolution_due_at` datetime, `first_response_status` integer default 0,
  `resolution_status` integer default 0, `first_response_met_at`,
  `resolution_met_at`, `breached_at` datetimes, timestamps.
- Enum dos status: `pending: 0, met: 1, breached: 2, not_measured: 3`.
- Índices: `(account_id, first_response_status)`, `(account_id, resolution_status)`,
  `first_response_due_at`, `resolution_due_at`.

Modelos: `CaktoSlaPolicy` (`belongs_to :account`, `has_many :conversation_slas`) e
`CaktoConversationSla` (`belongs_to :account, :conversation, :cakto_sla_policy`).
`Account has_many :cakto_sla_policies`; `Conversation has_one :cakto_sla`
(`class_name: 'CaktoConversationSla'`).

## API (Rails, `Api::V1::Accounts::*`, autorização Pundit)

Só quando `Current.account.feature_enabled?('cakto_sla')`; senão 404.

- `GET    /api/v1/accounts/:account_id/cakto_sla_policies` — qualquer agente.
- `POST   /api/v1/accounts/:account_id/cakto_sla_policies` — administrador.
- `GET    /api/v1/accounts/:account_id/cakto_sla_policies/:id`
- `PATCH  /api/v1/accounts/:account_id/cakto_sla_policies/:id` — administrador.
- `DELETE /api/v1/accounts/:account_id/cakto_sla_policies/:id` — administrador.

Corpo (`cakto_sla_policy`): `name`, `description`, `first_response_minutes`,
`resolution_minutes`, `inbox_ids: []`, `active`.

Resposta (jbuilder, um item):
```json
{ "id": 1, "name": "Suporte padrão", "description": "", "first_response_minutes": 15,
  "resolution_minutes": 480, "inbox_ids": [1, 2], "active": true,
  "created_at": 1790000000, "updated_at": 1790000000 }
```

Payload da conversa (`app/views/api/v1/models/_conversation.json.jbuilder` e
`app/views/api/v1/conversations/partials/_conversation.json.jbuilder`), chave
`cakto_sla`, `null` quando não há:
```json
{ "policy_id": 1, "policy_name": "Suporte padrão",
  "first_response_due_at": 1790000900, "resolution_due_at": 1790028800,
  "first_response_status": "pending", "resolution_status": "pending",
  "breached_at": null }
```
Timestamps em segundos (unix), como o resto do payload.

Relatório: `GET /api/v1/accounts/:account_id/cakto_sla/report?since=<unix>&until=<unix>&inbox_id=`
(administrador). Considera conversas criadas no intervalo.
```json
{ "totals": { "conversations": 120,
    "first_response": { "measured": 110, "met": 90, "breached": 15, "pending": 5 },
    "resolution":     { "measured": 110, "met": 70, "breached": 30, "pending": 10 } },
  "by_inbox": [ { "inbox_id": 1, "inbox_name": "WhatsApp", "conversations": 80,
                  "first_response": {…}, "resolution": {…} } ],
  "by_agent": [ { "assignee_id": 3, "name": "Ana", "conversations": 40,
                  "first_response": {…}, "resolution": {…} } ] }
```

## Backend: pontos de encaixe

- Listener `CaktoSlaListener < BaseListener` registrado em
  `app/dispatchers/async_dispatcher.rb` (`conversation_created`,
  `first_reply_created`, `conversation_resolved`).
- Job `CaktoSla::BreachJob` (`queue_as :scheduled_jobs`) chamado de
  `app/jobs/trigger_scheduled_items_job.rb` (a cada 5 min).
- Serviços puros e testáveis: `CaktoSla::ApplyPolicyService`,
  `CaktoSla::MarkFirstResponseService`, `CaktoSla::MarkResolutionService`,
  `CaktoSla::ReportService`.
- Specs rspec para modelos, listener, job, controller e report (a suíte roda no CI
  do fork em pull request; localmente não há Ruby 3.4).

## Frontend (Vue 3, `app/javascript/dashboard/`)

- Flag `CAKTO_SLA: 'cakto_sla'` em `featureFlags.js`.
- API client `api/caktoSla.js` (policies com `ApiClient` account-scoped; `report(params)`).
- Store `store/modules/caktoSla.js` (records, uiFlags, actions get/create/update/delete, report).
- Configurações: rota `settings/cakto-sla` (padrão de `labels`), item "SLA" no
  `Sidebar.vue` (ícone `i-lucide-timer`), tela com lista + formulário (nome,
  descrição, minutos de primeira resposta, minutos de resolução, caixas de
  entrada em multiseleção, ativo). Apenas administrador.
- Selo `CaktoSlaBadge.vue`: no card da lista (legado `ConversationCard.vue` e
  `components-next`) e no cabeçalho da conversa. Só quando `chat.cakto_sla`.
  Texto e cor derivados no cliente a partir dos vencimentos + status:
  - primeira resposta pendente: "Responder em 12m" (verde; âmbar quando falta
    < 20% do prazo; vermelho "Resposta atrasada há 5m" quando passou);
  - primeira resposta cumprida e resolução pendente: "Resolver em 1h 20m" (idem);
  - estourado (status `breached`): vermelho.
  Atualiza a cada 30 s. Sem SLA: não renderiza nada.
- Relatório: página "SLA" no menu de Relatórios com período (padrão: 7 dias) e
  filtro de caixa; cards de totais (% dentro do prazo) e duas tabelas (por caixa,
  por agente).
- i18n: `i18n/locale/pt_BR/caktoSla.json` e `en/caktoSla.json` (+ `SIDEBAR.CAKTO_SLA`
  em `settings.json` dos dois idiomas). Português primeiro, sem travessão longo.
- Testes vitest para o cálculo do selo (função pura `caktoSlaStatus.js`) e para o store.

## Adendo 22/09/2026: SLA por equipe (área)

Pedido do Ítalo: prazo por área, valendo a partir da transferência.

- `cakto_sla_policies.team_ids` (integer array, default `[]`): equipes cobertas. Uma
  equipe em no máximo uma política ativa (validar como `inbox_ids`).
- **Escolha da política** ao criar a conversa: primeiro a política que cobre
  `conversation.team_id` (se houver equipe), senão a que cobre a caixa. Sem nenhuma: sem SLA.
- **Transferência** (`TEAM_CHANGED`, ou `CONVERSATION_UPDATED` com `team_id` em
  `changed_attributes`, o que existir no dispatcher): se uma política ativa cobre a
  equipe nova, o registro `cakto_conversation_slas` da conversa é **reaplicado**:
  `cakto_sla_policy_id` passa a ser o da equipe, e todo prazo ainda `pending` ganha
  vencimento novo contado da transferência (`Time.current` / `event.timestamp` +
  minutos). Prazo já `met`/`breached` não muda; `not_measured` vira `pending` se a
  política nova mede aquele prazo. Se não havia registro, cria como na criação. Se a
  equipe nova não tem política, nada muda. Atividade na conversa: "SLA passou a ser da
  política X (equipe Y)".
- API: `cakto_sla_policy` aceita `team_ids: []` no create/update; jbuilder devolve
  `team_ids`. Relatório `by_team` já existe.
- Frontend (feito depois, em outro PR): multiseleção de equipes no formulário da
  política, ao lado das caixas.

## Adendo 22/09/2026: solicitante do ticket interno é avisado

- Ao criar o ticket (`CaktoTickets::CreateService`), o solicitante vira
  **participante** da conversa (`conversation_participants`), o que já dispara as
  notificações nativas de participante a cada resposta.
- Ao **resolver** um ticket interno (`CONVERSATION_RESOLVED` numa conversa com
  `additional_attributes['cakto_ticket']`), o sistema cria uma **nota privada**
  mencionando o solicitante no formato nativo de menção
  (`[@Nome](mention://user/<id>/<nome url-encoded>)`), com o texto
  "Seu ticket #<n> foi resolvido pela equipe <equipe>." — a menção dispara a
  notificação `conversation_mention` (sino, e-mail, push). Remetente da nota: quem
  resolveu (`Current.user`) quando houver; a menção não notifica o próprio remetente,
  então se o solicitante resolveu o próprio ticket não há aviso, o que é correto.
- Listener: `CaktoTicketsListener#conversation_resolved` no async dispatcher.
