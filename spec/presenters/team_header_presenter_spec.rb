require 'rails_helper'

RSpec.describe TeamHeaderPresenter do
  let(:view_context) { double('view_context', team_breadcrumb: '<nav>breadcrumb</nav>') }

  describe 'with nil entity' do
    subject(:presenter) { described_class.new(entity: nil, view_context: view_context) }

    it 'returns default name' do
      expect(presenter.name).to eq('Team')
    end

    it 'returns nil description' do
      expect(presenter.description).to be_nil
    end

    it 'returns nil point_of_contact' do
      expect(presenter.point_of_contact).to be_nil
    end

    it 'returns false for archived?' do
      expect(presenter.archived?).to be false
    end

    it 'returns empty breadcrumb' do
      expect(presenter.breadcrumb).to eq([])
    end
  end

  describe 'with valid entity' do
    let(:entity) do
      double('Team',
        name: 'Platform',
        description: 'Platform team',
        point_of_contact: 'platform@example.com',
        effective_contact: nil,
        archived?: false,
        id: '1'
      )
    end
    subject(:presenter) { described_class.new(entity: entity, view_context: view_context) }

    it 'returns entity name' do
      expect(presenter.name).to eq('Platform')
    end

    it 'returns entity description' do
      expect(presenter.description).to eq('Platform team')
    end

    it 'returns entity point_of_contact when no effective_contact' do
      expect(presenter.point_of_contact).to eq('platform@example.com')
    end

    it 'returns effective_contact when present' do
      allow(entity).to receive(:effective_contact).and_return('inherited@example.com')
      expect(presenter.point_of_contact).to eq('inherited@example.com')
    end

    it 'returns entity archived?' do
      expect(presenter.archived?).to be false
    end

    it 'returns breadcrumb' do
      expect(presenter.breadcrumb).to eq('<nav>breadcrumb</nav>')
    end
  end
end
