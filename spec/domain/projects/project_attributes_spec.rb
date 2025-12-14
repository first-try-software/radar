require 'spec_helper'
require 'domain/projects/project_attributes'

RSpec.describe ProjectAttributes do
  it 'stores name as a string' do
    attrs = described_class.new(name: 'Status')

    expect(attrs.name).to eq('Status')
  end

  it 'defaults description to empty string' do
    attrs = described_class.new(name: 'Status')

    expect(attrs.description).to eq('')
  end

  it 'defaults point_of_contact to empty string' do
    attrs = described_class.new(name: 'Status')

    expect(attrs.point_of_contact).to eq('')
  end

  it 'defaults archived to false' do
    attrs = described_class.new(name: 'Status')

    expect(attrs.archived).to be(false)
  end

  it 'defaults current_state to :new' do
    attrs = described_class.new(name: 'Status')

    expect(attrs.current_state).to eq(:new)
  end

  it 'converts nil current_state to :new' do
    attrs = described_class.new(name: 'Status', current_state: nil)

    expect(attrs.current_state).to eq(:new)
  end

  it 'returns a new instance with updated state via with_state' do
    attrs = described_class.new(name: 'Status')

    updated = attrs.with_state(:in_progress)

    expect(updated.current_state).to eq(:in_progress)
    expect(updated).not_to equal(attrs)
  end

  it 'returns archived status via archived?' do
    attrs = described_class.new(name: 'Status', archived: true)

    expect(attrs.archived?).to be(true)
  end

  describe 'name_valid?' do
    it 'returns true when name is present' do
      attrs = described_class.new(name: 'Status')

      expect(attrs.name_valid?).to be(true)
    end

    it 'returns false when name is blank' do
      attrs = described_class.new(name: '')

      expect(attrs.name_valid?).to be(false)
    end

    it 'returns false when name is only whitespace' do
      attrs = described_class.new(name: '   ')

      expect(attrs.name_valid?).to be(false)
    end
  end

  describe 'name_errors' do
    it 'returns empty array when name is valid' do
      attrs = described_class.new(name: 'Status')

      expect(attrs.name_errors).to eq([])
    end

    it 'returns error when name is blank' do
      attrs = described_class.new(name: '')

      expect(attrs.name_errors).to eq(['name must be present'])
    end
  end
end
