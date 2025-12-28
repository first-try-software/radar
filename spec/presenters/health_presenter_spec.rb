# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthPresenter do
  describe '#initialize' do
    it 'sets default values when nil is passed' do
      presenter = HealthPresenter.new(health: nil)

      expect(presenter.health).to eq(:not_available)
      expect(presenter.off_track_count).to eq(0)
      expect(presenter.at_risk_count).to eq(0)
      expect(presenter.total_count).to eq(0)
    end

    it 'uses provided values' do
      presenter = HealthPresenter.new(
        health: :on_track,
        raw_score: 0.75,
        off_track_count: 2,
        at_risk_count: 3,
        total_count: 10,
        methodology: 'Custom method'
      )

      expect(presenter.health).to eq(:on_track)
      expect(presenter.off_track_count).to eq(2)
      expect(presenter.at_risk_count).to eq(3)
      expect(presenter.total_count).to eq(10)
    end
  end

  describe '#health_css_class' do
    it 'converts underscores to hyphens' do
      presenter = HealthPresenter.new(health: :not_available)

      expect(presenter.health_css_class).to eq('not-available')
    end

    it 'handles simple statuses' do
      presenter = HealthPresenter.new(health: :on_track)

      expect(presenter.health_css_class).to eq('on-track')
    end
  end

  describe '#health_label' do
    it 'converts underscores to spaces and titleizes' do
      presenter = HealthPresenter.new(health: :at_risk)

      expect(presenter.health_label).to eq('At Risk')
    end
  end

  describe '#raw_score_display' do
    it 'returns N/A when raw_score is nil' do
      presenter = HealthPresenter.new(health: :on_track)

      expect(presenter.raw_score_display).to eq('N/A')
    end

    it 'shows positive score with plus sign' do
      presenter = HealthPresenter.new(health: :on_track, raw_score: 0.567)

      expect(presenter.raw_score_display).to eq('+0.57')
    end

    it 'shows negative score without plus sign' do
      presenter = HealthPresenter.new(health: :off_track, raw_score: -0.5)

      expect(presenter.raw_score_display).to eq('-0.5')
    end

    it 'shows zero with plus sign' do
      presenter = HealthPresenter.new(health: :at_risk, raw_score: 0.0)

      expect(presenter.raw_score_display).to eq('+0.0')
    end
  end

  describe '#show_off_track_detail?' do
    it 'returns true when off_track_count is positive' do
      presenter = HealthPresenter.new(health: :off_track, off_track_count: 1)

      expect(presenter.show_off_track_detail?).to be true
    end

    it 'returns false when off_track_count is zero' do
      presenter = HealthPresenter.new(health: :on_track, off_track_count: 0)

      expect(presenter.show_off_track_detail?).to be false
    end
  end

  describe '#off_track_detail' do
    it 'returns formatted detail string' do
      presenter = HealthPresenter.new(health: :at_risk, off_track_count: 2, total_count: 10)

      expect(presenter.off_track_detail).to eq('2 of 10 items off-track')
    end
  end

  describe '#show_at_risk_detail?' do
    it 'returns true when at_risk_count positive and off_track_count is zero' do
      presenter = HealthPresenter.new(health: :at_risk, off_track_count: 0, at_risk_count: 3)

      expect(presenter.show_at_risk_detail?).to be true
    end

    it 'returns false when off_track_count is positive' do
      presenter = HealthPresenter.new(health: :at_risk, off_track_count: 1, at_risk_count: 3)

      expect(presenter.show_at_risk_detail?).to be false
    end

    it 'returns false when at_risk_count is zero' do
      presenter = HealthPresenter.new(health: :on_track, off_track_count: 0, at_risk_count: 0)

      expect(presenter.show_at_risk_detail?).to be false
    end
  end

  describe '#at_risk_detail' do
    it 'returns formatted detail string' do
      presenter = HealthPresenter.new(health: :at_risk, at_risk_count: 3, total_count: 10)

      expect(presenter.at_risk_detail).to eq('3 of 10 items at-risk')
    end
  end

  describe '#methodology' do
    it 'returns provided methodology' do
      presenter = HealthPresenter.new(health: :on_track, methodology: 'Custom method')

      expect(presenter.methodology).to eq('Custom method')
    end

    it 'returns default methodology when not provided' do
      presenter = HealthPresenter.new(health: :on_track)

      expect(presenter.methodology).to eq('Weighted average of leaf project health scores.')
    end
  end
end
