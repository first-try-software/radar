require 'rails_helper'

RSpec.describe InitiativeEditModalPresenter do
  let(:view_context) { double('view_context', initiative_path: '/initiatives/1') }

  describe 'with nil entity' do
    subject(:presenter) { described_class.new(entity: nil, view_context: view_context) }

    it 'returns empty string for name' do
      expect(presenter.name).to eq('')
    end

    it 'returns empty string for description' do
      expect(presenter.description).to eq('')
    end

    it 'returns empty string for point_of_contact' do
      expect(presenter.point_of_contact).to eq('')
    end

    it 'returns false for archived?' do
      expect(presenter.archived?).to be false
    end

    it 'returns nil for update_path' do
      expect(presenter.update_path).to be_nil
    end
  end

  describe 'with valid entity' do
    let(:entity) do
      double('Initiative',
        name: 'Q1 Launch',
        description: 'Launch new product',
        point_of_contact: 'pm@example.com',
        archived?: true,
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
      expect(presenter.archived?).to be true
    end
  end
end
