# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConfidencePresenter do
  describe '#initialize' do
    it 'sets default values when nil is passed' do
      presenter = ConfidencePresenter.new(score: nil, level: nil, factors: nil)

      expect(presenter.score).to eq(0)
      expect(presenter.level).to eq(:low)
      expect(presenter.factors).to eq({})
    end

    it 'uses provided values' do
      factors = { biggest_drag: :variance }
      presenter = ConfidencePresenter.new(score: 85, level: :high, factors: factors)

      expect(presenter.score).to eq(85)
      expect(presenter.level).to eq(:high)
      expect(presenter.factors).to eq(factors)
    end
  end

  describe '#level_label' do
    it 'titleizes the level' do
      presenter = ConfidencePresenter.new(score: 50, level: :medium, factors: {})

      expect(presenter.level_label).to eq('Medium')
    end
  end

  describe '#level_css_class' do
    it 'returns the level as a string' do
      presenter = ConfidencePresenter.new(score: 50, level: :low, factors: {})

      expect(presenter.level_css_class).to eq('low')
    end
  end

  describe '#hint' do
    it 'returns hint for variance drag' do
      presenter = ConfidencePresenter.new(score: 50, level: :low, factors: { biggest_drag: :variance })

      expect(presenter.hint).to eq('Volatile health trend')
    end

    it 'returns hint for staleness drag' do
      presenter = ConfidencePresenter.new(score: 50, level: :low, factors: { biggest_drag: :staleness })

      expect(presenter.hint).to eq('Data growing stale')
    end

    it 'returns hint for coverage drag' do
      presenter = ConfidencePresenter.new(score: 50, level: :low, factors: { biggest_drag: :coverage })

      expect(presenter.hint).to eq('Update coverage is uneven')
    end

    it 'returns hint for insufficient_data drag' do
      presenter = ConfidencePresenter.new(score: 50, level: :low, factors: { biggest_drag: :insufficient_data })

      expect(presenter.hint).to eq('Building history...')
    end

    it 'returns nil when no recognized drag' do
      presenter = ConfidencePresenter.new(score: 50, level: :low, factors: { biggest_drag: :unknown })

      expect(presenter.hint).to be_nil
    end
  end

  describe '#show_hint?' do
    it 'returns true when hint present and level not high' do
      presenter = ConfidencePresenter.new(score: 50, level: :low, factors: { biggest_drag: :variance })

      expect(presenter.show_hint?).to be true
    end

    it 'returns false when level is high' do
      presenter = ConfidencePresenter.new(score: 90, level: :high, factors: { biggest_drag: :variance })

      expect(presenter.show_hint?).to be false
    end

    it 'returns false when no hint' do
      presenter = ConfidencePresenter.new(score: 50, level: :low, factors: {})

      expect(presenter.show_hint?).to be false
    end
  end

  describe '#ring_circumference' do
    it 'returns the ring circumference rounded to 1 decimal' do
      presenter = ConfidencePresenter.new(score: 50, level: :medium, factors: {})

      expected = (2 * Math::PI * 18).round(1)
      expect(presenter.ring_circumference).to eq(expected)
    end
  end

  describe '#ring_offset' do
    it 'calculates offset based on score percentage' do
      presenter = ConfidencePresenter.new(score: 50, level: :medium, factors: {})

      circumference = 2 * Math::PI * 18
      expected = (circumference - (50 / 100.0 * circumference)).round(1)
      expect(presenter.ring_offset).to eq(expected)
    end

    it 'returns full circumference for 0 score' do
      presenter = ConfidencePresenter.new(score: 0, level: :low, factors: {})

      expected = (2 * Math::PI * 18).round(1)
      expect(presenter.ring_offset).to eq(expected)
    end

    it 'returns 0 for 100 score' do
      presenter = ConfidencePresenter.new(score: 100, level: :high, factors: {})

      expect(presenter.ring_offset).to eq(0.0)
    end
  end
end
