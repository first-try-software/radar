require 'spec_helper'
require 'domain/projects/project_attributes'

RSpec.describe ProjectAttributes do
  it 'converts nil current_state to :new' do
    attrs = described_class.new(name: 'Radar', current_state: nil)

    expect(attrs.current_state).to eq(:new)
  end

  it 'returns a new instance with updated state via with_state' do
    attrs = described_class.new(name: 'Radar')

    updated = attrs.with_state(:in_progress)

    expect(updated.current_state).to eq(:in_progress)
    expect(updated).not_to equal(attrs)
  end

  describe 'valid?' do
    it 'returns true when name and state are valid' do
      attrs = described_class.new(name: 'Radar', current_state: :in_progress)

      expect(attrs.valid?).to be(true)
    end

    it 'returns false when name is blank' do
      attrs = described_class.new(name: '')

      expect(attrs.valid?).to be(false)
      expect(attrs.errors).to eq(['name must be present'])
    end

    it 'returns false when name is only whitespace' do
      attrs = described_class.new(name: '   ')

      expect(attrs.valid?).to be(false)
      expect(attrs.errors).to eq(['name must be present'])
    end

    it 'returns false when state is invalid' do
      attrs = described_class.new(name: 'Radar', current_state: :invalid)

      expect(attrs.valid?).to be(false)
      expect(attrs.errors).to eq(['state must be valid'])
    end
  end

  describe 'errors' do
    it 'returns an empty array when name and state are valid' do
      attrs = described_class.new(name: 'Radar', current_state: :in_progress)

      expect(attrs.errors).to eq([])
    end

    it 'returns "name must be present" when name is blank' do
      attrs = described_class.new(name: '')

      expect(attrs.errors).to eq(['name must be present'])
    end

    it 'returns "name must be present" when name is only whitespace' do
      attrs = described_class.new(name: '   ')

      expect(attrs.errors).to eq(['name must be present'])
    end

    it 'returns "state must be valid" when state is invalid' do
      attrs = described_class.new(name: 'Radar', current_state: :invalid)

      expect(attrs.errors).to eq(['state must be valid'])
    end
  end
end
