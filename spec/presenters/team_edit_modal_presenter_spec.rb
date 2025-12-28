require 'rails_helper'

RSpec.describe TeamEditModalPresenter do
  let(:view_context) { double('view_context', team_path: '/teams/1') }

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
      double('Team',
        name: 'Platform',
        description: 'Platform team',
        point_of_contact: 'platform@example.com',
        archived?: true,
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

    it 'returns entity point_of_contact' do
      expect(presenter.point_of_contact).to eq('platform@example.com')
    end

    it 'returns entity archived?' do
      expect(presenter.archived?).to be true
    end
  end
end
