require 'spec_helper'
require 'domain/projects/project_loaders'

RSpec.describe ProjectLoaders do
  it 'stores children loader' do
    loader = -> { [] }
    loaders = described_class.new(children: loader)

    expect(loaders.children).to eq(loader)
  end

  it 'stores parent loader' do
    loader = -> { nil }
    loaders = described_class.new(parent: loader)

    expect(loaders.parent).to eq(loader)
  end

  it 'stores health_updates loader' do
    loader = -> { [] }
    loaders = described_class.new(health_updates: loader)

    expect(loaders.health_updates).to eq(loader)
  end

  it 'stores weekly_health_updates loader' do
    loader = -> { [] }
    loaders = described_class.new(weekly_health_updates: loader)

    expect(loaders.weekly_health_updates).to eq(loader)
  end

  it 'defaults all loaders to nil' do
    loaders = described_class.new

    expect(loaders.children).to be_nil
    expect(loaders.parent).to be_nil
    expect(loaders.health_updates).to be_nil
    expect(loaders.weekly_health_updates).to be_nil
  end
end
