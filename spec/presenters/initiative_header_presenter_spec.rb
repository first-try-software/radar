require 'rails_helper'

RSpec.describe InitiativeHeaderPresenter do
  let(:view_context) { double('view_context', state_initiative_path: '/initiatives/1/state', initiative_breadcrumb: '<nav>breadcrumb</nav>') }

  describe 'with nil entity' do
    subject(:presenter) { described_class.new(entity: nil, view_context: view_context) }

    it 'returns default name' do
      expect(presenter.name).to eq('Initiative')
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

    it 'returns nil current_state' do
      expect(presenter.current_state).to be_nil
    end

    it 'returns nil state_path' do
      expect(presenter.state_path).to be_nil
    end

    it 'returns empty breadcrumb' do
      expect(presenter.breadcrumb).to eq([])
    end
  end

  describe 'with valid entity' do
    let(:entity) do
      double('Initiative',
        name: 'Q1 Launch',
        description: 'Launch new product',
        point_of_contact: 'pm@example.com',
        archived?: false,
        current_state: :in_progress,
        id: '1'
      )
    end
    subject(:presenter) { described_class.new(entity: entity, view_context: view_context) }

    it 'returns entity name' do
      expect(presenter.name).to eq('Q1 Launch')
    end

    it 'returns entity description' do
      expect(presenter.description).to eq('Launch new product')
    end

    it 'returns entity point_of_contact' do
      expect(presenter.point_of_contact).to eq('pm@example.com')
    end

    it 'returns entity archived?' do
      expect(presenter.archived?).to be false
    end

    it 'returns entity current_state' do
      expect(presenter.current_state).to eq(:in_progress)
    end

    it 'returns state_path' do
      expect(presenter.state_path).to eq('/initiatives/1/state')
    end

    it 'returns breadcrumb' do
      expect(presenter.breadcrumb).to eq('<nav>breadcrumb</nav>')
    end
  end
end
