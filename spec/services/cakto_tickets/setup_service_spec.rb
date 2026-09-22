require 'rails_helper'

describe CaktoTickets::SetupService do
  let(:account) { create(:account) }

  it 'creates the tickets inbox on an API channel without webhook and the conversation attributes' do
    inbox = described_class.new(account: account).perform

    expect(inbox.name).to eq('Tickets internos')
    expect(inbox.channel_type).to eq('Channel::Api')
    expect(inbox.channel.webhook_url).to be_nil
    definitions = account.custom_attribute_definitions.where(attribute_model: :conversation_attribute)
    expect(definitions.pluck(:attribute_key)).to match_array(%w[cakto_ticket_titulo cakto_ticket_solicitante cakto_ticket_seller
                                                                 cakto_ticket_origem])
    expect(definitions.pluck(:attribute_display_type).uniq).to eq(['text'])
  end

  it 'is idempotent' do
    first = described_class.new(account: account).perform

    expect { described_class.new(account: account).perform }.not_to change(Inbox, :count)
    expect(described_class.new(account: account).perform).to eq(first)
    expect(account.custom_attribute_definitions.count).to eq(4)
  end

  it 'ignores inboxes with the same name on other channels' do
    create(:inbox, account: account, name: 'Tickets internos')

    expect(described_class.new(account: account).perform.channel_type).to eq('Channel::Api')
  end
end
