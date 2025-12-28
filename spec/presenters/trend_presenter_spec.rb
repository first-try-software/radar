# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TrendPresenter do
  describe '#initialize' do
    it 'sets default values when nil is passed' do
      presenter = TrendPresenter.new(
        trend_data: nil,
        trend_direction: nil,
        trend_delta: nil,
        weeks_of_data: nil
      )

      expect(presenter.trend_data).to eq([])
      expect(presenter.trend_direction).to eq(:stable)
      expect(presenter.trend_delta).to eq(0.0)
      expect(presenter.weeks_of_data).to eq(0)
      expect(presenter.gradient_id).to eq("trend-gradient")
    end

    it 'uses provided values' do
      data = [{ health: :on_track, score: 1.0 }]
      presenter = TrendPresenter.new(
        trend_data: data,
        trend_direction: :up,
        trend_delta: 0.5,
        weeks_of_data: 3,
        gradient_id: "custom-gradient"
      )

      expect(presenter.trend_data).to eq(data)
      expect(presenter.trend_direction).to eq(:up)
      expect(presenter.trend_delta).to eq(0.5)
      expect(presenter.weeks_of_data).to eq(3)
      expect(presenter.gradient_id).to eq("custom-gradient")
    end
  end

  describe '#trend_css_class' do
    it 'returns trend class when sufficient data' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :up,
        trend_delta: 0.5,
        weeks_of_data: 2
      )

      expect(presenter.trend_css_class).to eq("trend-up")
    end

    it 'returns insufficient class when not enough data' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :up,
        trend_delta: 0.5,
        weeks_of_data: 1
      )

      expect(presenter.trend_css_class).to eq("trend-insufficient")
    end
  end

  describe '#delta_display' do
    it 'shows positive delta with plus sign' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :up,
        trend_delta: 0.567,
        weeks_of_data: 2
      )

      expect(presenter.delta_display).to eq("+0.57")
    end

    it 'shows negative delta without plus sign' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :down,
        trend_delta: -0.5,
        weeks_of_data: 2
      )

      expect(presenter.delta_display).to eq("-0.5")
    end

    it 'shows zero delta with plus sign' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 2
      )

      expect(presenter.delta_display).to eq("+0.0")
    end
  end

  describe '#delta_summary' do
    it 'combines delta display with weeks of data' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :up,
        trend_delta: 0.5,
        weeks_of_data: 4
      )

      expect(presenter.delta_summary).to eq("+0.5 (4 weeks)")
    end
  end

  describe '#sufficient_data?' do
    it 'returns true when 2 or more weeks' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 2
      )

      expect(presenter.sufficient_data?).to be true
    end

    it 'returns false when less than 2 weeks' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 1
      )

      expect(presenter.sufficient_data?).to be false
    end
  end

  describe '#single_week?' do
    it 'returns true when exactly 1 week' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 1
      )

      expect(presenter.single_week?).to be true
    end

    it 'returns false when not 1 week' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 2
      )

      expect(presenter.single_week?).to be false
    end
  end

  describe '#no_data?' do
    it 'returns true when 0 weeks' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 0
      )

      expect(presenter.no_data?).to be true
    end

    it 'returns false when 1 or more weeks' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 1
      )

      expect(presenter.no_data?).to be false
    end
  end

  describe '#no_data_message' do
    it 'returns singular message for single week' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 1
      )

      expect(presenter.no_data_message).to eq("1 week of data")
    end

    it 'returns insufficient message for no data' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 0
      )

      expect(presenter.no_data_message).to eq("Insufficient data")
    end
  end

  describe '#gradient_stops' do
    it 'returns empty array for empty data' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 0
      )

      expect(presenter.gradient_stops).to eq([])
    end

    it 'returns gradient stops with colors for each point' do
      data = [
        { health: :on_track, score: 1.0 },
        { health: :at_risk, score: 0.0 },
        { health: :off_track, score: -1.0 }
      ]
      presenter = TrendPresenter.new(
        trend_data: data,
        trend_direction: :down,
        trend_delta: -1.0,
        weeks_of_data: 3
      )

      stops = presenter.gradient_stops
      expect(stops.length).to eq(3)
      expect(stops[0]).to eq({ offset: 0, color: "#22c55e" })
      expect(stops[1]).to eq({ offset: 50, color: "#f59e0b" })
      expect(stops[2]).to eq({ offset: 100, color: "#ef4444" })
    end

    it 'handles single data point' do
      data = [{ health: :on_track, score: 1.0 }]
      presenter = TrendPresenter.new(
        trend_data: data,
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 1
      )

      stops = presenter.gradient_stops
      expect(stops.length).to eq(1)
      expect(stops[0]).to eq({ offset: 0, color: "#22c55e" })
    end
  end

  describe '#chart_points' do
    it 'returns empty array for empty data' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 0
      )

      expect(presenter.chart_points).to eq([])
    end

    it 'calculates x and y coordinates for each point' do
      data = [
        { health: :on_track, score: 1.0 },
        { health: :off_track, score: -1.0 }
      ]
      presenter = TrendPresenter.new(
        trend_data: data,
        trend_direction: :down,
        trend_delta: -1.0,
        weeks_of_data: 2
      )

      points = presenter.chart_points
      expect(points.length).to eq(2)
      expect(points[0][:x]).to eq(10.0)
      expect(points[0][:y]).to eq(5.0)
      expect(points[0][:health]).to eq(:on_track)
      expect(points[1][:x]).to eq(190.0)
      expect(points[1][:y]).to eq(45.0)
      expect(points[1][:health]).to eq(:off_track)
    end

    it 'handles single data point' do
      data = [{ health: :at_risk, score: 0.0 }]
      presenter = TrendPresenter.new(
        trend_data: data,
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 1
      )

      points = presenter.chart_points
      expect(points.length).to eq(1)
      expect(points[0][:x]).to eq(10.0)
      expect(points[0][:y]).to eq(25.0)
    end
  end

  describe '#polyline_points' do
    it 'returns empty string for empty data' do
      presenter = TrendPresenter.new(
        trend_data: [],
        trend_direction: :stable,
        trend_delta: 0.0,
        weeks_of_data: 0
      )

      expect(presenter.polyline_points).to eq("")
    end

    it 'returns space-separated coordinate pairs' do
      data = [
        { health: :on_track, score: 1.0 },
        { health: :off_track, score: -1.0 }
      ]
      presenter = TrendPresenter.new(
        trend_data: data,
        trend_direction: :down,
        trend_delta: -1.0,
        weeks_of_data: 2
      )

      expect(presenter.polyline_points).to eq("10.0,5.0 190.0,45.0")
    end
  end
end
